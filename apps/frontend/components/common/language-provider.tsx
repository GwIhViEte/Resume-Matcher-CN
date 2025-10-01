'use client';

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

import {
  AVAILABLE_LOCALES,
  DEFAULT_LOCALE,
  LOCALE_COOKIE,
  LOCALE_LABELS,
  LOCALE_STORAGE_KEY,
  type Locale,
  normalizeLocale,
} from '@/i18n/config';
import zhMessages from '@/i18n/messages/zh.json';
import enMessages from '@/i18n/messages/en.json';

type Messages = typeof zhMessages;

const ALL_MESSAGES: Record<Locale, Messages> = {
  'zh-CN': zhMessages,
  'en-US': enMessages,
};

type TranslationValues = Record<string, string | number>;

interface LanguageContextValue {
  locale: Locale;
  localeName: string;
  availableLocales: Array<{ value: Locale; label: string }>;
  setLocale: (locale: Locale) => void;
  t: (key: string, values?: TranslationValues) => string;
}

const LanguageContext = createContext<LanguageContextValue | undefined>(undefined);

function resolveMessage(messages: Messages, key: string): string | undefined {
  return key.split('.').reduce<unknown>((current, segment) => {
    if (current && typeof current === 'object') {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      return (current as Record<string, unknown>)[segment];
    }
    return undefined;
  }, messages) as string | undefined;
}

function formatMessage(message: string, values?: TranslationValues): string {
  if (!values) {
    return message;
  }

  return message.replace(/{{\s*([\w.-]+)\s*}}/g, (_, token: string) => {
    const replacement = values[token];
    return replacement !== undefined ? String(replacement) : `{{${token}}}`;
  });
}

function getStoredLocale(): Locale | undefined {
  if (typeof window === 'undefined') {
    return undefined;
  }

  const saved = window.localStorage.getItem(LOCALE_STORAGE_KEY);
  return saved ? normalizeLocale(saved) : undefined;
}

function persistLocale(locale: Locale) {
  if (typeof window === 'undefined') {
    return;
  }

  window.localStorage.setItem(LOCALE_STORAGE_KEY, locale);
  void fetch('/api/locale', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ locale }),
  }).catch(() => undefined);
}

export function LanguageProvider({
  initialLocale,
  children,
}: {
  initialLocale?: Locale;
  children: ReactNode;
}) {
  const [locale, setLocaleState] = useState<Locale>(
    normalizeLocale(initialLocale ?? DEFAULT_LOCALE),
  );

  useEffect(() => {
    const stored = getStoredLocale();
    if (stored && stored !== locale) {
      setLocaleState(stored);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (typeof document !== 'undefined') {
      document.documentElement.lang = locale;
    }
  }, [locale]);

  const setLocale = useCallback((next: Locale) => {
    const normalized = normalizeLocale(next);
    setLocaleState((current) => {
      if (current === normalized) {
        return current;
      }
      persistLocale(normalized);
      return normalized;
    });
  }, []);

  const translate = useCallback(
    (key: string, values?: TranslationValues) => {
      const activeMessages = ALL_MESSAGES[locale];
      const fallbackMessages = ALL_MESSAGES[DEFAULT_LOCALE];

      const message =
        resolveMessage(activeMessages, key) ??
        resolveMessage(fallbackMessages, key) ??
        key;

      return formatMessage(message, values);
    },
    [locale],
  );

  const contextValue = useMemo<LanguageContextValue>(
    () => ({
      locale,
      localeName: LOCALE_LABELS[locale],
      availableLocales: AVAILABLE_LOCALES,
      setLocale,
      t: translate,
    }),
    [locale, setLocale, translate],
  );

  return <LanguageContext.Provider value={contextValue}>{children}</LanguageContext.Provider>;
}

export function useI18n(): LanguageContextValue {
  const context = useContext(LanguageContext);
  if (!context) {
    throw new Error('useI18n must be used within a LanguageProvider');
  }
  return context;
}
