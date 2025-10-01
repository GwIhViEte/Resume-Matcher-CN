import os
import logging

from openai import OpenAI
from typing import Any, Dict
from fastapi.concurrency import run_in_threadpool

from ..exceptions import ProviderError
from .base import Provider, EmbeddingProvider
from ...core import settings

logger = logging.getLogger(__name__)


class OpenAIProvider(Provider):
    def __init__(self, api_key: str | None = None, model_name: str = settings.LL_MODEL,
                 opts: Dict[str, Any] = None):
        if opts is None:
            opts = {}

        api_key_source = None
        if api_key:
            api_key_source = "argument"
        else:
            if settings.LLM_API_KEY:
                api_key = settings.LLM_API_KEY
                api_key_source = "settings"
            else:
                env_key = os.getenv("OPENAI_API_KEY")
                if env_key:
                    api_key = env_key
                    api_key_source = "environment"

        logger.info("Initialising OpenAI provider (key source: %s)", api_key_source or "unknown")


        if not api_key:
            raise ProviderError("OpenAI API key is missing")
        # Use the base_url from settings
        self._client = OpenAI(api_key=api_key, base_url=settings.LLM_BASE_URL, timeout=120.0)
        self.model = model_name
        self.opts = opts
        self.instructions = ""

    def _generate_sync(self, prompt: str, options: Dict[str, Any], client: OpenAI | None = None) -> str:
        client = client or self._client
        try:
            # Note: The original code used a non-existent method `self._client.responses.create`.
            # The correct method for chat completions is `self._client.chat.completions.create`.
            # We also need to format the prompt correctly.
            response = client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": self.instructions or "You are a helpful assistant."},
                    {"role": "user", "content": prompt}
                ],
                **options,
            )
            return response.choices[0].message.content
        except Exception as e:
            raise ProviderError(f"OpenAI - error generating response: {e}") from e

    async def __call__(self, prompt: str, **generation_args: Any) -> str:
        myopts = {
            "temperature": self.opts.get("temperature", 0),
        }
        myopts.update(generation_args)

        request_api_key = myopts.pop("token", None) or myopts.pop("api_key", None)
        client = self._client
        if request_api_key:
            client = OpenAI(api_key=request_api_key, base_url=settings.LLM_BASE_URL, timeout=120.0)

        return await run_in_threadpool(self._generate_sync, prompt, myopts, client)


class OpenAIEmbeddingProvider(EmbeddingProvider):
    def __init__(
        self,
        api_key: str | None = None,
        embedding_model: str = settings.EMBEDDING_MODEL,
    ):
        api_key = api_key or settings.EMBEDDING_API_KEY or os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ProviderError("OpenAI API key is missing")
        # Use the base_url from settings
        self._client = OpenAI(api_key=api_key, base_url=settings.EMBEDDING_BASE_URL, timeout=120.0)
        self._model = embedding_model

    async def embed(self, text: str) -> list[float]:
        try:
            # The input text should be cleaned of newlines for embedding
            text_to_embed = text.replace("\n", " ")
            response = await run_in_threadpool(
                self._client.embeddings.create, input=[text_to_embed], model=self._model
            )
            return response.data[0].embedding
        except Exception as e:
            raise ProviderError(f"OpenAI - error generating embedding: {e}") from e
