'use client';

import JobDescriptionUploadTextArea from '@/components/jd-upload/text-area';
import BackgroundContainer from '@/components/common/background-container';
import { Suspense } from 'react';
import { useI18n } from '@/components/common/language-provider';

const ProvideJobDescriptionsPage = () => {
	const { t } = useI18n();

	return (
		<BackgroundContainer>
			<div className="flex flex-col items-center justify-center max-w-7xl">
				<h1 className="text-6xl font-bold text-center mb-12 text-white">
					{t('onboarding.jobs.title')}
				</h1>
				<p className="text-center text-gray-300 text-xl mb-8 max-w-xl mx-auto">
					{t('onboarding.jobs.subtitle')}
				</p>
				<Suspense fallback={<div>{t('onboarding.jobs.loading')}</div>}>
					<JobDescriptionUploadTextArea />
				</Suspense>
			</div>
		</BackgroundContainer>
	);
};

export default ProvideJobDescriptionsPage;
