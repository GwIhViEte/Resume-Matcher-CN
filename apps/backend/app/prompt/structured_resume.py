PROMPT = {
	'zh-CN': (
		"你是一台 JSON 抽取引擎。请将以下简历文本转换为完全符合给定 JSON 架构的结构化数据。\n"
		"请遵循以下规则：\n"
		"- 不要添加额外字段或说明。\n"
		"- 保留字段名称并输出有效 JSON。\n"
		"JSON 架构：\n{0}\n\n简历内容：\n{1}\n"
		"仅输出 JSON，不要包含其他内容。"
	),
	'en-US': (
		"You are a JSON extraction engine. Convert the resume text below into JSON matching the provided schema.\n"
		"Follow these rules:\n"
		"- Do not add extra fields or narration.\n"
		"- Preserve key names and output valid JSON only.\n"
		"Schema:\n{0}\n\nResume:\n{1}\n"
		"Return only the JSON object with no additional commentary."
	),
}
