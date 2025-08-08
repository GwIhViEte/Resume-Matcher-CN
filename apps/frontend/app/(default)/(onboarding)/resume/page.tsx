'use client';

import BackgroundContainer from '@/components/common/background-container';
import FileUpload from '@/components/common/file-upload';

export default function UploadResume() {
	return (
		<BackgroundContainer innerClassName="justify-start pt-16">
			<div className="w-full max-w-md mx-auto flex flex-col items-center gap-6">
				<h1 className="text-4xl font-bold text-center text-white mb-6">
					上传你的简历
				</h1>
				{/* 新增必填/选填字段说明 */}
				<div className="bg-gray-800/50 border border-gray-700 rounded-md p-4 text-sm text-gray-300 mb-8">
					<p className="mb-2 font-semibold text-white">📌 简历填写要求</p>
					<ul className="list-disc list-inside space-y-1">
					<li>
						<span className="text-red-400">必填</span>：
						个人信息（姓名、邮箱、电话、所在地）、求职方向/职位标题、教育背景、工作/实习经历
						</li>
						<li>
							<span className="text-green-400">选填</span>：
							项目经历、技能、科研工作、成就/荣誉、个人网站、LinkedIn、GitHub
							</li>
					</ul>
				</div>
				<p className="text-center text-gray-300 mb-8">
					将你的简历文件拖拽到下面，或点击以浏览文件。支持的格式：PDF、DOC、DOCX（最大 2 MB）。
				</p>
				<div className="w-full">
					<FileUpload />
				</div>
			</div>
		</BackgroundContainer>
	);
}
