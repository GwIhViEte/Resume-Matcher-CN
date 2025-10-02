import logging
import ollama

from typing import Any, Dict, List, Optional
from fastapi.concurrency import run_in_threadpool

from ..exceptions import ProviderError
from .base import Provider, EmbeddingProvider
from ...core import settings

logger = logging.getLogger(__name__)

class OllamaProvider(Provider):
    def __init__(self, model_name: str = settings.LL_MODEL, host: Optional[str] = None,
                 opts: Dict[str, Any] = None):
        if opts is None:
            opts = {}
        self.opts = opts
        self.model = model_name
        self._client = ollama.Client(host=host) if host else ollama.Client()
        installed_ollama_models = self._extract_installed_model_names()
        if model_name not in installed_ollama_models:
            try:
                self._client.pull(model_name)
            except Exception as e:
                raise ProviderError(
                    f"Ollama Model '{model_name}' could not be pulled. Please update your apps/backend/.env file or select from the installed models."
                ) from e

    def _extract_installed_model_names(self) -> List[str]:
        response = self._client.list()
        models = getattr(response, "models", None)
        if models is None:
            try:
                models = response["models"]  # type: ignore[index]
            except Exception:
                models = []

        results: List[str] = []
        for model_info in models:
            name = self._resolve_model_name(model_info)
            if name:
                results.append(name)
        return results

    @staticmethod
    async def _get_installed_models(host: Optional[str] = None) -> List[str]:
        """
        List all installed models.
        """

        def _list_sync() -> List[str]:
            client = ollama.Client(host=host) if host else ollama.Client()
            response = client.list()
            models = getattr(response, "models", None)
            if models is None:
                try:
                    models = response["models"]  # type: ignore[index]
                except Exception:
                    models = []
            results: List[str] = []
            for model_info in models:
                name = OllamaProvider._resolve_model_name(model_info)
                if name:
                    results.append(name)
            return results

        return await run_in_threadpool(_list_sync)

    @staticmethod
    def _resolve_model_name(model_info: Any) -> Optional[str]:
        if isinstance(model_info, dict):
            return model_info.get("name") or model_info.get("model")
        name = getattr(model_info, "name", None)
        if name:
            return name
        return getattr(model_info, "model", None)

    def _generate_sync(self, prompt: str, options: Dict[str, Any]) -> str:
        """
        Generate a response from the model.
        """
        try:
            response = self._client.generate(
                prompt=prompt,
                model=self.model,
                options=options,
            )
            return response["response"].strip()
        except Exception as e:
            logger.error(f"ollama sync error: {e}")
            raise ProviderError(f"Ollama - Error generating response: {e}") from e

    async def __call__(self, prompt: str, **generation_args: Any) -> str:
        if generation_args:
            logger.warning(f"OllamaProvider ignoring generation_args {generation_args}")
        myopts = self.opts # Ollama can handle all the options manager.py passes in.
        return await run_in_threadpool(self._generate_sync, prompt, myopts)


class OllamaEmbeddingProvider(EmbeddingProvider):
    def __init__(
        self,
        embedding_model: str = settings.EMBEDDING_MODEL,
        host: Optional[str] = None,
    ):
        self._model = embedding_model
        self._client = ollama.Client(host=host) if host else ollama.Client()

    async def embed(self, text: str) -> List[float]:
        """
        Generate an embedding for the given text.
        """
        try:
            response = await run_in_threadpool(
                self._client.embed,
                input=text,
                model=self._model,
            )
            embedding = self._extract_embedding(response)
            if embedding is None:
                raise KeyError("embedding")
            return embedding
        except Exception as e:
            logger.error(f"ollama embedding error: {e}")
            raise ProviderError(f"Ollama - Error generating embedding: {e}") from e

    @staticmethod
    def _extract_embedding(response: Any) -> Optional[List[float]]:
        if response is None:
            return None

        if isinstance(response, dict):
            if "embedding" in response and isinstance(response["embedding"], list):
                return response["embedding"]

            embeddings = response.get("embeddings")
            if isinstance(embeddings, list) and embeddings:
                first_item = embeddings[0]
                if isinstance(first_item, dict) and isinstance(first_item.get("embedding"), list):
                    return first_item["embedding"]
                if isinstance(first_item, list):
                    return first_item

        attr_embedding = getattr(response, "embedding", None)
        if isinstance(attr_embedding, list):
            return attr_embedding

        attr_embeddings = getattr(response, "embeddings", None)
        if isinstance(attr_embeddings, list) and attr_embeddings:
            first_item = attr_embeddings[0]
            if isinstance(first_item, dict) and isinstance(first_item.get("embedding"), list):
                return first_item["embedding"]
            if isinstance(first_item, list):
                return first_item

        return None
