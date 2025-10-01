'use client';

import BackgroundContainer from '@/components/common/background-container';
import FileUpload from '@/components/common/file-upload';
import { useI18n } from '@/components/common/language-provider';

export default function UploadResume() {
	const { t } = useI18n();

	return (
		<BackgroundContainer innerClassName="justify-start pt-16">
			<div className="w-full max-w-md mx-auto flex flex-col items-center gap-6">
				<h1 className="text-4xl font-bold text-center text-white mb-6">
					{t('onboarding.resume.title')}
				</h1>
				<div className="bg-gray-800/50 border border-gray-700 rounded-md p-4 text-sm text-gray-300 mb-8">
					<p className="mb-2 font-semibold text-white">{t('onboarding.resume.guidelines.title')}</p>
					<ul className="list-disc list-inside space-y-1">
						<li>
							<span className="text-red-400">{t('onboarding.resume.guidelines.required')}</span>：
							{t('onboarding.resume.guidelines.requiredList')}
						</li>
						<li>
							<span className="text-green-400">{t('onboarding.resume.guidelines.optional')}</span>：
							{t('onboarding.resume.guidelines.optionalList')}
						</li>
					</ul>
				</div>
				<p className="text-center text-gray-300 mb-8">{t('onboarding.resume.instructions')}</p>
				<div className="w-full">
					<FileUpload />
				</div>
			</div>
		</BackgroundContainer>
	);
}
