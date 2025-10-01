import pkgutil
import importlib
from typing import Dict

from app.prompt import __path__ as prompt_pkg_path
from app.i18n import DEFAULT_LOCALE


class PromptFactory:
    def __init__(self) -> None:
        self._prompts: Dict[str, str] = {}
        self._discover()

    def _discover(self) -> None:
        for finder, module_name, ispkg in pkgutil.iter_modules(prompt_pkg_path):
            if module_name.startswith("_") or module_name == "base":
                continue

            module = importlib.import_module(f"app.prompt.{module_name}")
            if hasattr(module, "PROMPT"):
                self._prompts[module_name] = getattr(module, "PROMPT")

    def list_prompts(self) -> Dict[str, str]:
        return self._prompts

    def get(self, name: str, locale: str | None = None) -> str:
        try:
            prompt = self._prompts[name]
        except KeyError as exc:  # noqa: TRY003
            raise KeyError(
                f"Prompt '{name}' not found. Available prompts: {list(self._prompts.keys())}"
            ) from exc

        if isinstance(prompt, dict):
            if locale and locale in prompt:
                return prompt[locale]
            return prompt.get(DEFAULT_LOCALE)

        return prompt
