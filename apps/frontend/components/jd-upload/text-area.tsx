'use client';

import React, { useState, useCallback } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Textarea } from '@/components/ui/textarea';
import { Button } from '@/components/ui/button';
import { useResumePreview } from '@/components/common/resume_previewer_context';
import { uploadJobDescriptions, improveResume } from '@/lib/api/resume';
import { useI18n } from '@/components/common/language-provider';

type SubmissionStatus = 'idle' | 'submitting' | 'success' | 'error';
type ImprovementStatus = 'idle' | 'improving' | 'error';

export default function JobDescriptionUploadTextArea() {
	const [text, setText] = useState('');
	const [flash, setFlash] = useState<{ type: 'error' | 'success'; message: string } | null>(null);
	const [submissionStatus, setSubmissionStatus] = useState<SubmissionStatus>('idle');
	const [improvementStatus, setImprovementStatus] = useState<ImprovementStatus>('idle');
	const [jobId, setJobId] = useState<string | null>(null);

	const { setImprovedData } = useResumePreview();
	const searchParams = useSearchParams();
	const router = useRouter();
	const { t, locale } = useI18n();

	const resumeId = searchParams.get('resume_id')!;
	const model = searchParams.get('model') || 'gpt-3.5-turbo';
	const token = searchParams.get('token');

	const handleChange = useCallback(
		(e: React.ChangeEvent<HTMLTextAreaElement>) => {
			setText(e.target.value);
			setFlash(null);
			if (submissionStatus !== 'idle') setSubmissionStatus('idle');
		},
		[submissionStatus],
	);

	const handleUpload = useCallback(
		async (event: React.FormEvent) => {
			event.preventDefault();
			const trimmed = text.trim();
			if (!trimmed) {
				setFlash({ type: 'error', message: t('jobForm.flash.empty') });
				return;
			}
			if (!resumeId) {
				setFlash({ type: 'error', message: t('jobForm.flash.missingResume') });
				return;
			}

			setSubmissionStatus('submitting');
			try {
				const id = await uploadJobDescriptions([trimmed], resumeId, model, token, locale);
				setJobId(id);
				setSubmissionStatus('success');
				setFlash({ type: 'success', message: t('jobForm.flash.success') });
			} catch (error) {
				console.error(error);
				setSubmissionStatus('error');
				setFlash({ type: 'error', message: (error as Error).message });
			}
		},
		[text, resumeId, model, token, locale, t],
	);

	const handleImprove = useCallback(async () => {
		if (!jobId) return;

		setImprovementStatus('improving');
		try {
			const preview = await improveResume(resumeId, jobId, model, token, locale);
			setImprovedData(preview);
			router.push('/dashboard');
		} catch (error) {
			console.error(error);
			setImprovementStatus('error');
			setFlash({ type: 'error', message: (error as Error).message });
		}
	}, [resumeId, jobId, model, token, locale, setImprovedData, router]);

	const isNextDisabled = text.trim() === '' || submissionStatus === 'submitting';

	return (
		<form onSubmit={handleUpload} className="p-4 mx-auto w-full max-w-xl">
			{flash && (
				<div
					className={`p-3 mb-4 text-sm rounded-md ${flash.type === 'error'
						? 'bg-red-50 border border-red-200 text-red-800 dark:bg-red-900/20 dark:border-red-800/30 dark:text-red-300'
						: 'bg-green-50 border border-green-200 text-green-800 dark:bg-green-900/20 dark:border-green-800/30 dark:text-green-300'
					}`}
					role="alert"
				>
					<p>{flash.message}</p>
				</div>
			)}

			<div className="mb-6 relative">
				<label
					htmlFor="jobDescription"
					className="bg-zinc-950/80 text-white absolute start-1 top-0 z-10 block -translate-y-1/2 px-2 text-xs font-medium group-has-disabled:opacity-50"
				>
					{t('jobForm.label')} <span className="text-red-500">*</span>
				</label>
				<Textarea
					id="jobDescription"
					rows={15}
					value={text}
					onChange={handleChange}
					required
					aria-required="true"
					placeholder={t('jobForm.placeholder')}
					className="w-full bg-gray-800/30 focus:ring-1 border rounded-md dark:border-gray-600 focus:border-blue-500 focus:ring-blue-500/50 border-gray-300 min-h-[300px]"
				/>
			</div>

			<div className="flex justify-end pt-4">
				<Button
					type="submit"
					disabled={isNextDisabled}
					aria-disabled={isNextDisabled}
					className={`font-semibold py-2 px-6 rounded flex items-center justify-center min-w-[90px] transition-all duration-200 ease-in-out ${isNextDisabled
						? 'bg-gray-400 dark:bg-gray-600 text-gray-600 dark:text-gray-400 cursor-not-allowed'
						: 'bg-blue-600 hover:bg-blue-700 text-white dark:bg-blue-500 dark:hover:bg-blue-600'
						}`}
				>
					{submissionStatus === 'submitting' ? (
						<>
							<svg
								className="animate-spin -ml-1 mr-2 h-4 w-4 text-white"
								xmlns="http://www.w3.org/2000/svg"
								fill="none"
								viewBox="0 0 24 24"
								aria-hidden="true"
							>
								<circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
								<path
									className="opacity-75"
									fill="currentColor"
									d="M4 12a8 8 0 0 1 8-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 0 1 4 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
								/>
							</svg>
							<span>{t('jobForm.submit.loading')}</span>
						</>
					) : submissionStatus === 'success' ? (
						<span>{t('jobForm.submit.success')}</span>
					) : (
						<span>{t('jobForm.submit.default')}</span>
					)}
				</Button>
			</div>

			{submissionStatus === 'success' && jobId && (
				<div className="flex justify-end mt-2">
					<Button
						onClick={handleImprove}
						disabled={improvementStatus === 'improving'}
						className="font-semibold py-2 px-6 rounded min-w-[90px] bg-green-600 hover:bg-green-700 text-white"
					>
						{improvementStatus === 'improving'
							? t('jobForm.optimize.loading')
							: t('jobForm.optimize.cta')}
					</Button>
				</div>
			)}
		</form>
	);
}
