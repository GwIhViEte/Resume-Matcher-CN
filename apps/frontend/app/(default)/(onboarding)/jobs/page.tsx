import JobDescriptionUploadTextArea from '@/components/jd-upload/text-area';
import BackgroundContainer from '@/components/common/background-container';
import { Suspense } from 'react';

const ProvideJobDescriptionsPage = () => {
	return (
		<BackgroundContainer>
			<div className="flex flex-col items-center justify-center max-w-7xl">
				<h1 className="text-6xl font-bold text-center mb-12 text-white">
					提供职位描述
				</h1>
				<p className="text-center text-gray-300 text-xl mb-8 max-w-xl mx-auto">
					在下方粘贴最多三个职位描述，我们将用它们与你的简历进行对比，以找到最佳匹配。
				</p>
				<Suspense fallback={<div>正在加载输入框...</div>}>
					<JobDescriptionUploadTextArea />
				</Suspense>
			</div>
		</BackgroundContainer>
	);
};

export default ProvideJobDescriptionsPage;
