PROMPT = {
	'zh-CN': (
		"你是一台 JSON 抽取引擎。请将以下职位描述转换为完全符合给定 JSON 架构的结构化数据。\n"
		"请遵循以下规则：\n"
		"- 不要添加额外字段或说明。\n"
		"- 日期使用 YYYY-MM-DD 格式。\n"
		"- URL 字段应符合 URI 规范。\n"
		"- 严格按照字段名称输出，并仅输出有效 JSON。\n"
		"JSON 架构：\n{0}\n\n职位描述：\n{1}\n"
		"请只输出 JSON，勿包含其他内容。"
	),
	'en-US': (
		"You are a JSON extraction engine. Convert the job posting below into JSON matching the provided schema exactly.\n"
		"Follow these rules:\n"
		"- Do not add extra fields or prose.\n"
		"- Use YYYY-MM-DD for all dates.\n"
		"- Ensure URLs are valid URIs.\n"
		"- Keep the structure and keys unchanged and output only valid JSON.\n"
		"Schema:\n{0}\n\nJob Posting:\n{1}\n"
		"Return only the JSON object with no additional commentary."
	),
}
