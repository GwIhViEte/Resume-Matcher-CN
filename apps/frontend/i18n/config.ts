export const SUPPORTED_LOCALES = ['zh-CN', 'en-US'] as const;

export type Locale = (typeof SUPPORTED_LOCALES)[number];

export const DEFAULT_LOCALE: Locale = 'zh-CN';

export const LOCALE_COOKIE = 'resume-matcher-locale';

export const LOCALE_STORAGE_KEY = 'resume-matcher-locale';

export const LOCALE_LABELS: Record<Locale, string> = {
  'zh-CN': '中文',
  'en-US': 'English',
};

const NORMALIZED_LOCALE_MAP: Record<string, Locale> = {
  zh: 'zh-CN',
  'zh-cn': 'zh-CN',
  'zh-hans': 'zh-CN',
  'zh-hant': 'zh-CN',
  en: 'en-US',
  'en-us': 'en-US',
  'en-gb': 'en-US',
};

export const AVAILABLE_LOCALES: Array<{ value: Locale; label: string }> = SUPPORTED_LOCALES.map(
  (value) => ({
    value,
    label: LOCALE_LABELS[value],
  }),
);

export function isLocale(value?: string | null): value is Locale {
  if (!value) {
    return false;
  }
  return SUPPORTED_LOCALES.includes(value as Locale);
}

export function normalizeLocale(value?: string | null): Locale {
  if (!value) {
    return DEFAULT_LOCALE;
  }

  if (isLocale(value)) {
    return value;
  }

  const lowered = value.toLowerCase();
  if (NORMALIZED_LOCALE_MAP[lowered]) {
    return NORMALIZED_LOCALE_MAP[lowered];
  }

  const languagePart = lowered.split('-')[0];
  if (NORMALIZED_LOCALE_MAP[languagePart]) {
    return NORMALIZED_LOCALE_MAP[languagePart];
  }

  const matched = SUPPORTED_LOCALES.find((locale) => locale.toLowerCase() === lowered);
  if (matched) {
    return matched;
  }

  return DEFAULT_LOCALE;
}
