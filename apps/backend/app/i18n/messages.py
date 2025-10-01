MESSAGES = {
    'zh-CN': {
        'errors': {
            'file': {
                'invalid_type': '文件类型不受支持。仅允许上传 PDF 或 DOCX 文件。',
                'empty': '上传的文件为空，请选择有效的文件。',
                'unsupported': '不支持的文件类型：{file_type}',
            },
            'auth': {
                'invalid_token': '高级模型的 Token 无效、过期或缺失。',
            },
            'request': {
                'missing_content_type': '缺少 Content-Type 请求头。',
                'invalid_content_type': 'Content-Type 无效，仅支持：{allowed}。',
            },
            'resume': {
                'pdf_extract_failed': 'PDF 文件解析失败：{error}',
                'docx_extract_failed': 'Word 文档解析失败：{error}',
                'no_text': '无法从文档中提取文本，请确认文件包含可解析的文本内容。',
                'store_structured_failed': '存储结构化简历数据失败：{error}',
                'validation_failed': '简历验证失败：{details}',
                'id_required': '必须提供 resume_id。',
                'fetch_failed': '获取简历数据时出错。',
                'not_found': '未找到 ID 为 {resume_id} 的简历。',
                'parsing_failed': '解析 ID 为 {resume_id} 的简历时发生错误。',
                'keyword_missing': '无法提取简历关键词，无法继续优化。',
            },
            'job': {
                'not_found': '未找到 ID 为 {job_id} 的职位。',
                'parsing_failed': '解析 ID 为 {job_id} 的职位时发生错误。',
                'fetch_failed': '获取职位数据时出错。',
                'keyword_missing': '无法提取职位关键词，无法继续优化。',
                'id_required': '必须提供 job_id。',
            },
            'analysis': {
                'unavailable': '未能生成分析详情。',
            },
            'generic': '抱歉，发生未知错误。',
        },
        'responses': {
            'job_uploaded': '职位描述上传成功。',
            'resume_uploaded': '简历上传成功。',
            'token_generated': '令牌生成成功。',
        },
        'analysis': {
            'fallback_details': '未能生成分析详情。',
            'fallback_commentary': '',
            'fallback_improvements': [],
            'stream_start': '正在分析简历与职位描述……',
            'stream_complete': '分析完成。',
        },
        'prompts': {
            'resume_improvement': (
                '你是一名资深的简历优化专家和人才招聘顾问。你的任务是根据提供的职位描述和提取的职位关键词，修改下面的简历，使其尽可能匹配该职位要求，并最大化简历与职位关键词的余弦相似度。\n'
                '要求：\n'
                '- 仔细阅读职位描述与关键词列表，并自然地融入相关技能与经验。\n'
                '- 必要时重写、补充或删除内容，以更好地符合职位要求。\n'
                '- 保持专业、自然的语气，并尽可能使用量化成果与行动动词。\n'
                '- 当前的余弦相似度分数是 {current_score:.2f}。请提升该分数。\n'
                '- 改写后的简历必须使用{target_language}撰写。\n'
                '- 只输出改进后的简历内容，格式为 Markdown，不要添加额外说明。\n\n'
                '职位描述：\n'
                '{job}\n\n'
                '提取的职位关键词：\n'
                '{job_keywords}\n\n'
                '原始简历：\n'
                '{resume}\n\n'
                '提取的简历关键词：\n'
                '{resume_keywords}\n'
            ),
            'analysis': (
                '你是一名资深的职业规划顾问。根据提供的原始简历、改进后的简历与职位描述，分析两者的差异。原始匹配分数为 {original_score:.2f}，改进后的分数为 {new_score:.2f}。\n'
                '请使用{target_language}输出结果，并且必须返回一个 JSON 对象，包含 "details"、"commentary" 和 "improvements"：\n'
                '- "details"：一句话概述主要的改动。\n'
                '- "commentary"：一段文字说明这些改动为何能提升匹配度。\n'
                '- "improvements"：数组，列出进一步优化建议，每项包含 "suggestion" 字段。\n\n'
                '原始简历：\n{original_resume}\n\n'
                '改进后的简历：\n{improved_resume}\n\n'
                '职位描述：\n{job_description}\n\n'
                '仅返回 JSON 对象，不要包含额外解释。'
            ),
            'resume_preview': (
                '请根据以下改进后的简历内容，生成符合 resume_preview JSON 架构的结构化数据：\n'
                '{schema}\n\n'
                '改进后的简历：\n{resume}\n\n'
                '仅返回 JSON 数据。'
            ),
        },
    },
    'en-US': {
        'errors': {
            'file': {
                'invalid_type': 'Invalid file type. Only PDF and DOCX files are allowed.',
                'empty': 'The uploaded file is empty. Please choose a valid file.',
                'unsupported': 'Unsupported file type: {file_type}',
            },
            'auth': {
                'invalid_token': 'Token for premium models is invalid, expired, or missing.',
            },
            'request': {
                'missing_content_type': 'Content-Type header is missing.',
                'invalid_content_type': 'Invalid Content-Type. Allowed values: {allowed}.',
            },
            'resume': {
                'pdf_extract_failed': 'Failed to extract text from PDF file: {error}',
                'docx_extract_failed': 'Failed to extract text from Word document: {error}',
                'no_text': 'Unable to extract text from the document. Ensure it contains readable text.',
                'store_structured_failed': 'Failed to store structured resume data: {error}',
                'validation_failed': 'Resume validation failed: {details}',
                'id_required': 'Parameter resume_id is required.',
                'fetch_failed': 'Error fetching resume data.',
                'not_found': 'Resume with ID {resume_id} was not found.',
                'parsing_failed': 'Failed to parse resume with ID {resume_id}.',
                'keyword_missing': 'Resume keywords are missing. Cannot continue improvement.',
            },
            'job': {
                'not_found': 'Job with ID {job_id} was not found.',
                'parsing_failed': 'Failed to parse job with ID {job_id}.',
                'fetch_failed': 'Error fetching job data.',
                'keyword_missing': 'Job keywords are missing. Cannot continue improvement.',
                'id_required': 'Parameter job_id is required.',
            },
            'analysis': {
                'unavailable': 'Analysis could not be generated.',
            },
            'generic': 'Sorry, something went wrong.',
        },
        'responses': {
            'job_uploaded': 'Job descriptions processed successfully.',
            'resume_uploaded': 'Resume uploaded successfully.',
            'token_generated': 'Token generated successfully.',
        },
        'analysis': {
            'fallback_details': 'Analysis could not be generated.',
            'fallback_commentary': '',
            'fallback_improvements': [],
            'stream_start': 'Analyzing resume and job description…',
            'stream_complete': 'Analysis complete.',
        },
        'prompts': {
            'resume_improvement': (
                'You are an experienced resume optimisation expert. Use the provided job description and keywords to revise the resume so that it aligns with the role and maximises cosine similarity.\n'
                'Guidelines:\n'
                '- Carefully review the job description and keyword list, weaving relevant skills and experience naturally.\n'
                '- Rewrite, expand, or remove content when necessary to fit the role requirements.\n'
                '- Maintain a professional tone and favour quantified achievements and action verbs.\n'
                '- The current cosine similarity score is {current_score:.2f}. Aim to improve it.\n'
                '- The improved resume must be written in {target_language}.\n'
                '- Output only the improved resume in Markdown format without additional commentary.\n\n'
                'Job description:\n'
                '{job}\n\n'
                'Extracted job keywords:\n'
                '{job_keywords}\n\n'
                'Original resume:\n'
                '{resume}\n\n'
                'Extracted resume keywords:\n'
                '{resume_keywords}\n'
            ),
            'analysis': (
                'You are a senior career advisor. Compare the original and improved resumes against the job description. The original match score was {original_score:.2f} and the new score is {new_score:.2f}.\n'
                'Respond in {target_language} and return a JSON object with "details", "commentary", and "improvements":\n'
                '- "details": one sentence summarising the main changes.\n'
                '- "commentary": a paragraph explaining why the changes improve the match.\n'
                '- "improvements": an array of further suggestions, each containing a "suggestion" field.\n\n'
                'Original resume:\n{original_resume}\n\n'
                'Improved resume:\n{improved_resume}\n\n'
                'Job description:\n{job_description}\n\n'
                'Return only the JSON object with no extra commentary.'
            ),
            'resume_preview': (
                'Using the improved resume below, produce structured data that matches the resume_preview JSON schema.\n'
                '{schema}\n\n'
                'Improved resume:\n{resume}\n\n'
                'Return only the JSON representation.'
            ),
        },
    },
}
