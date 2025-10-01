from __future__ import annotations

from typing import Any, Dict

from fastapi import Request

from app.i18n.config import DEFAULT_LOCALE, SUPPORTED_LOCALES
from app.i18n.messages import MESSAGES


def normalize_locale(value: str | None) -> str:
    if not value:
        return DEFAULT_LOCALE

    candidate = value.strip().lower()
    for locale in SUPPORTED_LOCALES:
        if locale.lower() == candidate:
            return locale

    candidate_language = candidate.split('-')[0]
    for locale in SUPPORTED_LOCALES:
        if locale.split('-')[0].lower() == candidate_language:
            return locale

    return DEFAULT_LOCALE


def translate(key: str, locale: str, **kwargs: Any) -> str:
    locale_messages: Dict[str, Any] = MESSAGES.get(locale, {})
    fallback_messages: Dict[str, Any] = MESSAGES[DEFAULT_LOCALE]

    message = _resolve(locale_messages, key)
    if message is None:
        message = _resolve(fallback_messages, key)

    if message is None:
        return key

    if kwargs:
        return message.format(**kwargs)
    return message


def _resolve(messages: Dict[str, Any], dotted_key: str) -> Any:
    current: Any = messages
    for part in dotted_key.split('.'):
        if isinstance(current, dict) and part in current:
            current = current[part]
        else:
            return None
    return current


def extract_preferred_locale(request: Request) -> str:
    query_locale = request.query_params.get('locale')
    if query_locale:
        return normalize_locale(query_locale)

    header = request.headers.get('accept-language')
    if header:
        for segment in header.split(','):
            language = segment.split(';')[0].strip()
            if language:
                return normalize_locale(language)

    return DEFAULT_LOCALE


def get_target_language(locale: str) -> str:
    if normalize_locale(locale) == 'en-US':
        return 'English'
    return '简体中文'
