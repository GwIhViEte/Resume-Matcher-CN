import React from 'react';
import { useI18n } from '@/components/common/language-provider';

interface PersonalInfo {
	name?: string;
	title?: string;
	email?: string;
	phone?: string;
	location?: string;
	website?: string;
	linkedin?: string;
	github?: string;
}

interface Experience {
	id: number;
	title?: string;
	company?: string;
	location?: string;
	years?: string;
	description?: string[];
}

interface Education {
	id: number;
	institution?: string;
	degree?: string;
	years?: string;
	description?: string;
}

interface ResumeData {
	personalInfo?: PersonalInfo;
	summary?: string;
	experience?: Experience[];
	education?: Education[];
	skills?: string[];
}

interface ResumeProps {
	resumeData: ResumeData;
}

const Resume: React.FC<ResumeProps> = ({ resumeData }) => {
	const { t } = useI18n();
	const { personalInfo, summary, experience, education, skills } = resumeData;

const renderContactDetail = (
	label: string,
	value?: string,
	hrefPrefix = '',
	enforceHttps = false,
) => {
	if (!value) return null;
	let finalHrefPrefix = hrefPrefix;
	if (
		enforceHttps &&
		!value.startsWith('http') &&
		!value.startsWith('//')
	) {
		finalHrefPrefix = 'https://';
	}
		const href = finalHrefPrefix + value;
		const isLink = finalHrefPrefix.startsWith('http') || finalHrefPrefix.startsWith('mailto:') || finalHrefPrefix.startsWith('tel:');

		return (
			<div className="text-[13px] sm:text-sm break-words">
				<span className="font-semibold text-gray-200">{label}：</span>{' '}
				{isLink ? (
					<a
						href={href}
						target="_blank"
						rel="noopener noreferrer"
						className="text-blue-400 hover:underline break-all"
					>
						{value}
					</a>
				) : (
					<span className="break-words text-gray-300">{value}</span>
				)}
			</div>
		);
	};

	return (
		<div className="font-mono bg-gray-950 text-gray-300 w-full max-w-4xl mx-auto border border-gray-700 rounded-xl shadow-lg px-4 py-5 sm:px-6 sm:py-6">
			{personalInfo && (
				<div className="text-center mb-5 sm:mb-6 pb-4 border-b border-gray-800">
					{personalInfo.name && (
						<h1 className="text-2xl sm:text-3xl md:text-4xl font-bold mb-1.5 text-white">
							{personalInfo.name}
						</h1>
					)}
					{personalInfo.title && (
						<h2 className="text-base sm:text-lg md:text-xl text-gray-400 mb-3">
							{personalInfo.title}
						</h2>
					)}
					<div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-y-2 gap-x-3 text-left px-1 sm:px-2">
					{renderContactDetail(t('resumeCard.contact.email'), personalInfo.email, 'mailto:')}
					{renderContactDetail(t('resumeCard.contact.phone'), personalInfo.phone, 'tel:')}
					{renderContactDetail(t('resumeCard.contact.location'), personalInfo.location)}
					{renderContactDetail(t('resumeCard.contact.website'), personalInfo.website, '', true)}
					{renderContactDetail(t('resumeCard.contact.linkedin'), personalInfo.linkedin, '', true)}
					{renderContactDetail(t('resumeCard.contact.github'), personalInfo.github, '', true)}
					</div>
				</div>
			)}

			{summary && (
				<section className="mb-6 sm:mb-8">
					<h3 className="text-lg sm:text-xl font-semibold border-b border-gray-800 pb-2 mb-3 text-gray-100">
						{t('resumeCard.sections.summary')}
					</h3>
					<p className="text-sm sm:text-base leading-relaxed whitespace-pre-line">{summary}</p>
				</section>
			)}

			{experience && experience.length > 0 && (
				<section className="mb-6 sm:mb-8">
					<h3 className="text-lg sm:text-xl font-semibold border-b border-gray-800 pb-2 mb-4 text-gray-100">
						{t('resumeCard.sections.experience')}
					</h3>
					{experience.map((exp) => (
						<div key={exp.id} className="mb-5 pl-3 sm:pl-4 border-l-2 border-blue-500">
							{exp.title && (
								<h4 className="text-base sm:text-lg font-semibold text-gray-100">{exp.title}</h4>
							)}
							{(exp.company || exp.location) && (
								<p className="text-sm sm:text-base font-medium text-gray-400">
									{exp.company} {exp.location && `| ${exp.location}`}
								</p>
							)}
							{exp.years && <p className="text-xs sm:text-sm text-gray-500 mb-2">{exp.years}</p>}
							{exp.description && exp.description.length > 0 && (
								<ul className="list-disc list-outside ml-4 sm:ml-5 text-sm sm:text-base space-y-1.5">
									{exp.description.map((desc, index) => (
										<li key={index} className="break-words">
											{desc}
										</li>
									))}
								</ul>
							)}
						</div>
					))}
				</section>
			)}

			{education && education.length > 0 && (
				<section className="mb-6 sm:mb-8">
					<h3 className="text-lg sm:text-xl font-semibold border-b border-gray-800 pb-2 mb-4 text-gray-100">
						{t('resumeCard.sections.education')}
					</h3>
					{education.map((edu) => (
						<div key={edu.id} className="mb-5 pl-3 sm:pl-4 border-l-2 border-green-500">
							{edu.institution && (
								<h4 className="text-base sm:text-lg font-semibold text-gray-100">{edu.institution}</h4>
							)}
							{edu.degree && (
								<p className="text-sm sm:text-base font-medium text-gray-400">{edu.degree}</p>
							)}
							{edu.years && <p className="text-xs sm:text-sm text-gray-500 mb-2">{edu.years}</p>}
							{edu.description && (
								<p className="text-sm sm:text-base leading-relaxed break-words">{edu.description}</p>
							)}
						</div>
					))}
				</section>
			)}

			{skills && skills.length > 0 && (
				<section>
					<h3 className="text-lg sm:text-xl font-semibold border-b border-gray-800 pb-2 mb-3 text-gray-100">
						{t('resumeCard.sections.skills')}
					</h3>
					<div className="flex flex-wrap gap-2">
						{skills.map(
							(skill, index) =>
								skill && (
									<span
										key={index}
										className="bg-gray-700 text-gray-200 text-xs sm:text-sm font-medium px-3 py-1 rounded-full"
									>
										{skill}
									</span>
								),
						)}
					</div>
				</section>
			)}
		</div>
	);
};

export default Resume;
