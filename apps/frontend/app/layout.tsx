import type { Metadata } from 'next';
import { cookies, headers } from 'next/headers';
import { Geist, Space_Grotesk } from 'next/font/google';
import './(default)/css/globals.css';
import { ResumePreviewProvider } from '@/components/common/resume_previewer_context';
import { LanguageProvider } from '@/components/common/language-provider';
import { LanguageSwitcher } from '@/components/common/language-switcher';
import {
  DEFAULT_LOCALE,
  LOCALE_COOKIE,
  type Locale,
  normalizeLocale,
} from '@/i18n/config';

const spaceGrotesk = Space_Grotesk({
  variable: '--font-space-grotesk',
  subsets: ['latin'],
  display: 'swap',
});

const geist = Geist({
  variable: '--font-geist',
  subsets: ['latin'],
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'Resume Matcher',
  description: 'Build your resume with Resume Matcher',
  applicationName: 'Resume Matcher',
  keywords: ['resume', 'matcher', 'job', 'application'],
};

async function detectInitialLocale(): Promise<Locale> {
  const cookieStore = await cookies();
  const cookieLocale = cookieStore.get(LOCALE_COOKIE)?.value;
  if (cookieLocale) {
    return normalizeLocale(cookieLocale);
  }

  const headerStore = await headers(); const acceptLanguage = headerStore.get('accept-language');
  if (acceptLanguage) {
    const candidate = acceptLanguage
      .split(',')
      .map((entry) => entry.split(';')[0]?.trim())
      .find((value) => Boolean(value));

    if (candidate) {
      return normalizeLocale(candidate);
    }
  }

  return DEFAULT_LOCALE;
}

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const initialLocale = await detectInitialLocale();

  return (
    <html lang={initialLocale}>
      <body
        className={`${geist.variable} ${spaceGrotesk.variable} antialiased bg-white text-gray-900`}
      >
        <LanguageProvider initialLocale={initialLocale}>
          <LanguageSwitcher />
          <ResumePreviewProvider>
            <div>{children}</div>
          </ResumePreviewProvider>
        </LanguageProvider>
      </body>
    </html>
  );
}
