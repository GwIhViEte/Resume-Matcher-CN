import { NextResponse } from 'next/server';

import { DEFAULT_LOCALE, LOCALE_COOKIE, normalizeLocale, type Locale } from '@/i18n/config';

type Payload = {
  locale?: string;
};

export async function POST(request: Request) {
  let desiredLocale: Locale = DEFAULT_LOCALE;

  try {
    const data = (await request.json()) as Payload;
    desiredLocale = normalizeLocale(data.locale);
  } catch (error) {
    // ignore malformed payloads and fall back to default locale
  }

  const response = NextResponse.json({ locale: desiredLocale });
  response.cookies.set({
    name: LOCALE_COOKIE,
    value: desiredLocale,
    path: '/',
    httpOnly: false,
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 365,
  });
  return response;
}
