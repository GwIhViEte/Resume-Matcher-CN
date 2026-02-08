<div align="center">

[![Resume Matcher](assets/page_2.png)](https://www.resumematcher.fyi)

# Resume Matcher 中文增强版

本仓库在上游开源项目 [resume-matcher](https://github.com/srbhr/resume-matcher) 基础上，对中文用户体验进行了全面优化，同时保留与原项目一致的部署与扩展方式。

上游项目[resume-matcher](https://github.com/srbhr/resume-matcher)已支持多语言，故本项目停更。

</div>

## ✨ 功能亮点

- 🌏 **双语界面** —— 右上角可在简体中文 / English 之间切换，后台 API 会随语言返回对应文案。
- 📝 **字段提示** —— 上传简历页清晰区分必填与选填信息，降低首次使用门槛。
- 📤 **直观上传体验** —— 支持拖拽上传 PDF / DOC / DOCX（≤ 2 MB），内置格式与大小校验。
- 🧠 **职位分析** —— 解析职位描述并提取关键词，辅助评估岗位匹配度。
- 🎯 **匹配优化** —— LLM 自动生成改进版简历，并提供可操作的优化建议。
- 🔒 **本地友好** —— 与上游项目共享部署脚本，方便自托管与二次开发。

## 🚀 快速开始

```bash
git clone https://github.com/GwIhViEte/Resume-Mather-CN.git
cd Resume-Mather-CN

# 安装前端依赖
npm install

# 安装后端依赖（需要 Python ≥ 3.9）
pip install -r requirements.txt

# 启动前端（Next.js）
cd apps/frontend
npm run dev
```

在 Windows 环境下，也可以使用一键脚本并按需指定网络模式：

```powershell
./setup.ps1 -NetworkProfile auto
```

执行时脚本会根据网络连通性自动选择国内或官方源；如需手动指定，可传入 `-NetworkProfile china` 或 `-NetworkProfile global`。

Windows用户查看[Windows安装文档](Setup-Windows.md)。

Linux用户文档`待实现/编写`


## 🤝 贡献指南

- 所有 PR 需包含变更说明及验证方式；如涉及界面或 API 变更，请附截图或示例响应。
- 欢迎提交 Issue，讨论中文场景下的更多优化点。

## 📄 License

本项目继承上游项目的开源许可，具体内容请参阅 `LICENSE` 文件。
