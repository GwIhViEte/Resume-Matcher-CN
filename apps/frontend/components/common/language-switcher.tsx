'use client';

import { AVAILABLE_LOCALES, LOCALE_LABELS, type Locale } from '@/i18n/config';
import { useI18n } from '@/components/common/language-provider';

const toggleOrder: Record<Locale, Locale> = {
  'zh-CN': 'en-US',
  'en-US': 'zh-CN',
};

export function LanguageSwitcher() {
  const { locale, setLocale, t } = useI18n();
  const nextLocale = toggleOrder[locale];
  const nextLabel = LOCALE_LABELS[nextLocale];

  return (
    <button
      type="button"
      onClick={() => setLocale(nextLocale)}
      className="fixed top-4 right-4 z-50 rounded-full border border-white/20 bg-black/40 px-4 py-1 text-sm text-white backdrop-blur transition hover:bg-black/60"
      aria-label={t('languageSwitcher.tooltip')}
      title={t('language.switchTo', { localeName: LOCALE_LABELS[nextLocale] })}
    >
      <span className="font-medium">{LOCALE_LABELS[locale]}</span>
      <span className="mx-1 text-white/60">/</span>
      <span className="font-medium text-white/80">{nextLabel}</span>
    </button>
  );
}

export function LanguageMenu() {
  const { locale, setLocale, t } = useI18n();

  return (
    <div className="inline-flex overflow-hidden rounded-full border border-white/20 bg-black/40 text-xs text-white">
      {AVAILABLE_LOCALES.map(({ value, label }) => (
        <button
          key={value}
          type="button"
          onClick={() => setLocale(value)}
          className={`px-3 py-1 transition ${
            value === locale ? 'bg-white/80 text-black font-semibold' : 'hover:bg-white/20'
          }`}
          aria-label={t('language.switchTo', { localeName: label })}
        >
          {label}
        </button>
      ))}
    </div>
  );
}
