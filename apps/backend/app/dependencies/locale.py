from fastapi import Request

from app.i18n import extract_preferred_locale


async def get_request_locale(request: Request) -> str:
    locale = extract_preferred_locale(request)
    request.state.locale = locale
    return locale
