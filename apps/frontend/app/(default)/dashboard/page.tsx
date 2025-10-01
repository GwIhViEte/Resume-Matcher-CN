// File: apps/frontend/app/dashboard/page.tsx

'use client';

import React from 'react';
import BackgroundContainer from '@/components/common/background-container';
import JobListings from '@/components/dashboard/job-listings';
import ResumeAnalysis from '@/components/dashboard/resume-analysis';
import Resume from '@/components/dashboard/resume-component';
import { useResumePreview } from '@/components/common/resume_previewer_context';
import { useI18n } from '@/components/common/language-provider';

interface AnalyzedJobData {
	title: string;
	company: string;
	location: string;
}

const mockResumeData = {
	personalInfo: {
		name: '艾达·洛夫莱斯',
		title: '软件工程师 & 远见者',
		email: 'ada.lovelace@example.com',
		phone: '+1-234-567-8900',
		location: '英国伦敦',
		website: 'analyticalengine.dev',
		linkedin: 'linkedin.com/in/adalovelace',
		github: 'github.com/adalovelace',
	},
	summary:
		'开创性的计算机程序员，具有扎实的数学和分析思维基础。以编写第一套由机器执行的算法而闻名。希望寻找具有挑战性的机会，将分析技能应用于现代计算问题。',
	experience: [
		{
			id: 1,
			title: '合作者 & 算法设计师',
			company: '查尔斯·巴贝奇分析机项目',
			location: '英国伦敦',
			years: '1842 - 1843',
			description: [
				'开发了首个旨在在计算机上实现的已发表算法——查尔斯·巴贝奇的分析机。',
				'翻译了路易吉·梅纳布雷亚关于分析机的回忆录，并添加了大量注释（G 注释），其中包含该算法。',
				'预见到计算机可以超越简单计算，设想了其在音乐和艺术方面的应用。',
			],
		},
	],
	education: [
		{
			id: 1,
			institution: '自学 & 私人辅导',
			degree: '数学与科学',
			years: '19世纪早期',
			description:
				'在著名数学家奥古斯都·德·摩根等导师的指导下广泛学习数学与科学。',
		},
	],
	skills: [
		'算法设计',
		'分析性思维',
		'数学建模',
		'计算理论',
		'技术写作',
		'法语（翻译）',
		'符号逻辑',
	],
};

export default function DashboardPage() {
	const { improvedData } = useResumePreview();
	const { t } = useI18n();

	if (!improvedData) {
		return (
			<BackgroundContainer className="min-h-screen" innerClassName="bg-zinc-950">
				<div className="flex items-center justify-center h-full p-6 text-gray-400 text-center">
					{t('dashboard.empty')}
				</div>
			</BackgroundContainer>
		);
	}

	const { data } = improvedData;
	const { resume_preview: resumePreview, new_score: newScore } = data;
	const preview = resumePreview ?? mockResumeData;
	const percentageScore = Math.round(newScore * 100);

	const handleJobUpload = async (text: string): Promise<AnalyzedJobData | null> => {
		void text;
		alert(t('dashboard.jobAnalysisNotImplemented'));
		return null;
	};

	return (
		<BackgroundContainer className="min-h-screen" innerClassName="bg-zinc-950 backdrop-blur-sm overflow-auto">
			<div className="w-full h-full overflow-auto py-8 px-4 sm:px-6 lg:px-8">
				<div className="container mx-auto">
					<div className="mb-10">
						<h1 className="text-3xl font-semibold pb-2 text-white">
							{t('dashboard.heading.prefix')}{' '}
							<span className="bg-gradient-to-r from-pink-400 to-purple-400 text-transparent bg-clip-text">
								{t('dashboard.heading.highlight')}
							</span>{' '}
							{t('dashboard.heading.suffix')}
						</h1>
						<p className="text-gray-300 text-lg">{t('dashboard.description')}</p>
					</div>

					<div className="grid grid-cols-1 md:grid-cols-3 gap-8">
						<div className="space-y-8">
							<section>
								<JobListings onUploadJob={handleJobUpload} />
							</section>
							<section>
								<ResumeAnalysis
									score={percentageScore}
									details={improvedData.data.details ?? ''}
									commentary={improvedData.data.commentary ?? ''}
									improvements={improvedData.data.improvements ?? []}
								/>
							</section>
						</div>

						<div className="md:col-span-2">
							<div className="bg-gray-900/70 backdrop-blur-sm p-6 rounded-lg shadow-xl h-full flex flex-col border border-gray-800/50">
								<div className="mb-6">
									<h2 className="text-2xl font-bold text-white mb-1">{t('dashboard.resumePanel.title')}</h2>
									<p className="text-gray-400 text-sm">{t('dashboard.resumePanel.caption')}</p>
								</div>
								<div className="flex-grow overflow-auto">
									<Resume resumeData={preview} />
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>
		</BackgroundContainer>
	);
}
