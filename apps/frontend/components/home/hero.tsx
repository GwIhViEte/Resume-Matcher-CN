'use client';

import Link from 'next/link';
import BackgroundContainer from '@/components/common/background-container';
import GitHubStarBadge from '@/components/common/github-star-badge';
import { useI18n } from '@/components/common/language-provider';

export default function Hero() {
  const { t } = useI18n();

  return (
    <BackgroundContainer>
      <div className="mx-auto w-full max-w-6xl px-4 sm:px-6">
        <div className="flex flex-col items-center pt-10 pb-8 sm:pt-12 sm:pb-10 md:pt-16 md:pb-12">
          <div className="mb-6 sm:mb-10 md:mb-14 flex items-center justify-center">
            <div className="scale-95 sm:scale-100">
              <GitHubStarBadge />
            </div>
          </div>

          <h1 className="text-center font-semibold tracking-tight leading-tight text-4xl sm:text-6xl lg:text-8xl bg-clip-text text-transparent bg-[linear-gradient(to_right,theme(colors.sky.500),theme(colors.pink.400),theme(colors.violet.600),theme(colors.blue.300),theme(colors.purple.400),theme(colors.pink.300),theme(colors.sky.500))] bg-[length:200%_auto] motion-safe:animate-[gradient_8s_linear_infinite]">
            {t('hero.title')}
          </h1>

          <p className="mt-4 md:mt-6 --font-space-grotesk text-center text-base sm:text-lg md:text-xl bg-gradient-to-br from-pink-400 via-blue-400 to-violet-600 bg-clip-text text-transparent">
            {t('hero.subtitle')}
          </p>

          <div className="mt-6 md:mt-8">
            <Link
              href="/resume"
              className="group relative inline-flex h-11 sm:h-12 overflow-hidden rounded-full p-[1px] focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-sky-500 focus-visible:ring-offset-slate-950"
            >
              <span className="absolute inset-[-1000%] motion-safe:animate-[spin_2s_linear_infinite] bg-[conic-gradient(from_90deg_at_50%_50%,#3A59D1_0%,#7AC6D2_50%,#3A59D1_100%)]" />
              <span className="inline-flex h-full w-full cursor-pointer items-center justify-center rounded-full bg-slate-950 px-4 sm:px-5 py-1.5 text-sm sm:text-base font-medium text-gray-100 backdrop-blur-3xl">
                {t('hero.cta')}
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 0.3 0.3"
                  fill="#FFF"
                  xmlns="http://www.w3.org/2000/svg"
                  className="ml-2 h-4 w-4 transition-transform duration-200 ease-in-out group-hover:translate-x-1"
                >
                  <path d="M.166.046a.02.02 0 0 1 .028 0l.09.09a.02.02 0 0 1 0 .028l-.09.09A.02.02 0 0 1 .166.226L.22.17H.03a.02.02 0 0 1 0-.04h.19L.166.074a.02.02 0 0 1 0-.028" />
                </svg>
              </span>
            </Link>
          </div>
        </div>
      </div>
    </BackgroundContainer>
  );
}
