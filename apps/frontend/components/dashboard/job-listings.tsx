'use client';

import React, { useState } from 'react';
import PasteJobDescription from './paste-job-description';
import { useI18n } from '@/components/common/language-provider';

interface Job {
	id?: number;
	title: string;
	company: string;
	location: string;
}

type AnalyzedJobData = Pick<Job, 'title' | 'company' | 'location'>;

interface JobListingsProps {
	onUploadJob: (text: string) => Promise<AnalyzedJobData | null>;
}

const JobListings: React.FC<JobListingsProps> = ({ onUploadJob }) => {
	const [isModalOpen, setIsModalOpen] = useState(false);
	const [analyzedJob, setAnalyzedJob] = useState<AnalyzedJobData | null>(null);
	const [isAnalyzing, setIsAnalyzing] = useState(false);
	const { t } = useI18n();

	const handleOpenModal = () => {
		setIsModalOpen(true);
	};

	const handleCloseModal = () => setIsModalOpen(false);

	const handlePasteAndAnalyzeJob = async (text: string) => {
		setIsAnalyzing(true);
		setAnalyzedJob(null);
		try {
			const jobData = await onUploadJob(text);
			setAnalyzedJob(jobData);
			if (!jobData) {
				console.warn(t('jobListings.log.noResult'));
			}
		} catch (error) {
			console.error(t('jobListings.log.error'), error);
			setAnalyzedJob(null);
		} finally {
			setIsAnalyzing(false);
			handleCloseModal();
		}
	};

	return (
		<div className="bg-gray-900/80 backdrop-blur-sm p-6 rounded-lg shadow-xl border border-gray-800/50">
			<h2 className="text-2xl font-bold text-white mb-1">{t('jobListings.heading')}</h2>
			<p className="text-gray-400 mb-6 text-sm">
				{analyzedJob ? t('jobListings.intro.analyzed') : t('jobListings.intro.empty')}
			</p>
			{isAnalyzing ? (
				<div className="text-center text-gray-400 py-8">
					<p>{t('jobListings.analyzing')}</p>
				</div>
			) : analyzedJob ? (
				<div className="space-y-4">
					<div className="p-4 bg-gray-700 rounded-md shadow-md">
						<h3 className="text-lg font-semibold text-gray-100">{analyzedJob.title}</h3>
						<p className="text-sm text-gray-300">{analyzedJob.company}</p>
						<p className="text-xs text-gray-400 mt-1">{analyzedJob.location}</p>
					</div>
					<button
						onClick={handleOpenModal}
						className="w-full text-center block bg-green-600 hover:bg-green-700 text-white font-medium py-2.5 px-4 rounded-md transition-colors duration-200 text-sm mt-4"
					>
						{t('jobListings.cta.another')}
					</button>
				</div>
			) : (
				<div className="text-center text-gray-400 py-8 flex flex-col justify-center items-center">
					<p className="mb-3">{t('jobListings.empty')}</p>
					<button
						onClick={handleOpenModal}
						className="inline-block bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-md transition-colors duration-200 text-sm"
					>
						{t('jobListings.cta.upload')}
					</button>
				</div>
			)}
			{isModalOpen && (
				<PasteJobDescription
					onClose={handleCloseModal}
					onPaste={handlePasteAndAnalyzeJob}
				/>
			)}
		</div>
	);
};

export default JobListings;
