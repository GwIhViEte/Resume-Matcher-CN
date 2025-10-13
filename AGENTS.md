# Repository Guidelines

## Project Structure & Module Organization
- `apps/backend`：FastAPI 服务，按照 `app/{api,core,services,schemas}` 分层，领域逻辑放在 `services`，Pydantic 模型驻留 `schemas`。
- `apps/frontend`：Next.js + TypeScript 界面，页面入口位于 `app`，可复用视图放在 `components`，共享逻辑放入 `hooks` 与 `lib`。
- `assets`：包含品牌与静态资源，供前后端共用；新增文件前确认是否已存在相同资源。
- `docs`：存放项目文档；任何跨团队知识最好追加于此。
- 根目录脚本：`Makefile`、`setup.sh` 与 `deploy.sh` 封装常用流程；保持脚本幂等并避免写入仓库外路径。

## Build, Test, and Development Commands
- `npm run install`：一次性安装前端依赖并使用 `uv` 配置后端虚拟环境。
- `npm run dev` 或 `make run-dev`：并行启动前后端开发服务，默认端口 `3000` 与 `8000`。
- `npm run build`：产出前端 Next.js 产物并执行后端构建校验；用于准备生产部署。
- `npm run start`：在已构建产物上同时引导 FastAPI 与 Next.js 进程。
- `npm run lint` / `apps/frontend npm run format`：分别运行 ESLint 与 Prettier；提交前确保无错误输出。

## Coding Style & Naming Conventions
- 前端遵循 TypeScript 严格模式，组件使用 PascalCase，hooks 使用 `useXxx`，文件命名倾向 kebab-case。
- Tailwind 样式按原子类从布局到修饰排序；公共 class 统一定义在 `lib` 助手或 `tailwind.config.js` 中。
- 后端遵循 PEP8 四空格缩进，模块按单一职责拆分；依赖注入放在 `dependencies`，服务层返回 Pydantic 模型以保持 LSP。
- 任何跨层交互优先依赖接口或抽象类，避免直接耦合具体实现。

## Testing Guidelines
- 仓库目前未集成自动化测试；新增功能必须附带验证说明或自建轻量测试。
- 后端推荐在 `apps/backend/tests` 使用 `pytest` 与 `httpx.AsyncClient` 覆盖 API 行为，测试文件命名 `test_<module>.py`。
- 前端建议在 `apps/frontend/__tests__` 采用 `@testing-library/react` 或 Playwright 进行组件与端到端校验，并在 PR 中粘贴运行命令及摘要。

## Commit & Pull Request Guidelines
- 仓库历史采用简洁中文摘要（示例：`修复BUG、安装菜单添加选择语言功能`），首行限制 50 字符，必要时追加英文说明。
- 提交前保证 `npm run lint`、`npm run build` 通过，并在描述中列出执行结果。
- PR 必须包含背景、变更摘要、测试或验证步骤、UI 改动截图（如涉及界面），并引用相关 Issue；保持讨论集中在单一主题。

## Security & Configuration Tips
- 使用 `.env` 或本地密钥管理器存储敏感配置，绝不提交到版本库。
- 为本地运行提供最小权限的 API 密钥，并在 README 或 `docs` 中记录配置信息更新。
