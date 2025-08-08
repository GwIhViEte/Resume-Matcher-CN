import React from 'react';

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
	console.log('Rendering Resume Component with data:', resumeData);
	const { personalInfo, summary, experience, education, skills } = resumeData;

	// 辅助函数：仅在存在值时渲染联系方式
	const renderContactDetail = (label: string, value?: string, hrefPrefix: string = '') => {
		if (!value) return null;
		let finalHrefPrefix = hrefPrefix;
		if (
			['网站', 'LinkedIn', 'GitHub'].includes(label) &&
			!value.startsWith('http') &&
			!value.startsWith('//')
		) {
			finalHrefPrefix = 'https://';
		}
		const href = finalHrefPrefix + value;
		const isLink =
			finalHrefPrefix.startsWith('http') ||
			finalHrefPrefix.startsWith('mailto:') ||
			finalHrefPrefix.startsWith('tel:');

		return (
			<div className="text-sm">
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
					<span className="break-all text-gray-300">{value}</span>
				)}
			</div>
		);
	};

	return (
		<div className="font-mono bg-gray-950 text-gray-300 p-4 shadow-lg rounded-lg max-w-4xl mx-auto border border-gray-600">
			{/* --- 个人信息 --- */}
			{personalInfo && (
				<div className="text-center mb-4 text-md pb-6 border-gray-700">
					{personalInfo.name && (
						<h1 className="text-3xl font-bold mb-2 text-white">{personalInfo.name}</h1>
					)}
					{personalInfo.title && (
						<h2 className="text-xl text-gray-400 mb-4">{personalInfo.title}</h2>
					)}
					<div className="grid grid-cols-3 gap-1 text-left px-2">
						{renderContactDetail('邮箱', personalInfo.email, 'mailto:')}
						{renderContactDetail('电话', personalInfo.phone, 'tel:')}
						{renderContactDetail('地址', personalInfo.location)}
						{renderContactDetail('网站', personalInfo.website)}
						{renderContactDetail('LinkedIn', personalInfo.linkedin)}
						{renderContactDetail('GitHub', personalInfo.github)}
					</div>
				</div>
			)}

			{/* --- 摘要 --- */}
			{summary && (
				<div className="mb-8">
					<h3 className="text-xl font-semibold border-b border-gray-700 pb-2 mb-3 text-gray-100">
						摘要
					</h3>
					<p className="text-sm leading-relaxed">{summary}</p>
				</div>
			)}

			{/* --- 工作经历 --- */}
			{experience && experience.length > 0 && (
				<div className="mb-8">
					<h3 className="text-xl font-semibold border-b border-gray-700 pb-2 mb-4 text-gray-100">
						工作经历
					</h3>
					{experience.map((exp) => (
						<div key={exp.id} className="mb-5 pl-4 border-l-2 border-blue-500">
							{exp.title && (
								<h4 className="text-lg font-semibold text-gray-100">{exp.title}</h4>
							)}
							{exp.company && (
								<p className="text-md font-medium text-gray-400">
									{exp.company} {exp.location && `| ${exp.location}`}
								</p>
							)}
							{exp.years && <p className="text-sm text-gray-500 mb-2">{exp.years}</p>}
							{exp.description && exp.description.length > 0 && (
								<ul className="list-disc list-outside ml-5 text-sm space-y-1">
									{exp.description.map((desc, index) => (
										<li key={index}>{desc}</li>
									))}
								</ul>
							)}
						</div>
					))}
				</div>
			)}

			{/* --- 教育经历 --- */}
			{education && education.length > 0 && (
				<div className="mb-8">
					<h3 className="text-xl font-semibold border-b border-gray-700 pb-2 mb-4 text-gray-100">
						教育经历
					</h3>
					{education.map((edu) => (
						<div key={edu.id} className="mb-5 pl-4 border-l-2 border-green-500">
							{edu.institution && (
								<h4 className="text-lg font-semibold text-gray-100">
									{edu.institution}
								</h4>
							)}
							{edu.degree && (
								<p className="text-md font-medium text-gray-400">{edu.degree}</p>
							)}
							{edu.years && <p className="text-sm text-gray-500 mb-2">{edu.years}</p>}
							{edu.description && <p className="text-sm">{edu.description}</p>}
						</div>
					))}
				</div>
			)}

			{/* --- 技能 --- */}
			{skills && skills.length > 0 && (
				<div>
					<h3 className="text-xl font-semibold border-b border-gray-700 pb-2 mb-3 text-gray-100">
						技能
					</h3>
					<div className="flex flex-wrap gap-2">
						{skills.map(
							(skill, index) =>
								skill && (
									<span
										key={index}
										className="bg-gray-700 text-gray-200 text-xs font-medium px-3 py-1 rounded-full"
									>
										{skill}
									</span>
								),
						)}
					</div>
				</div>
			)}
		</div>
	);
};

export default Resume;
