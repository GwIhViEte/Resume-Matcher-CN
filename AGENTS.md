# Repository Guidelines

## Project Structure & Module Organization
- `apps/frontend/`: Next.js 前端应用，页面位于 `app/`，可复用 UI 存放在 `components/`，公共 Hook 位于 `hooks/`，静态资源集中在 `public/`。
- `apps/backend/`: FastAPI 服务，业务逻辑按 `core/`、`services/`、`models/`、`schemas/` 分层，入口是 `app/main.py`。
- `docs/` 与 `assets/` 存放文档与媒体；自动化脚本集中在根目录 `setup.sh`、`setup.ps1`、`Makefile`。

## Build, Test, and Development Commands
- `npm install`：安装前端依赖；`npm run install:backend` 使用 `uv` 初始化后端环境。
- `npm run dev`：并行启动前后端开发环境；可使用 `npm run dev:frontend` 或 `npm run dev:backend` 定向调试。
- `npm run build`：构建前端并触发后端检查；`make run-prod` 在生产模式下启动完整栈。

## Coding Style & Naming Conventions
- 缩进统一为两个空格，LF 行尾，UTF-8 编码，提交前移除尾随空白并保留文件末尾换行。
- 前端 TypeScript 组件使用 PascalCase，Hook 以 `use` 前缀；运行 `npm run lint` 使用 ESLint 校验并保持 Tailwind 工具类按布局→颜色→状态排序。
- 后端 Pydantic 模型以 `*Schema` 结尾，服务类以 `*Service` 命名，路由置于 `app/api`，避免跨层直接耦合。

## Testing Guidelines
- 目标覆盖率 ≥80%。新增功能需在 `apps/frontend/__tests__/` 使用 Vitest/Playwright 或在 `apps/backend/tests/` 使用 Pytest/FastAPI `TestClient`。
- 前端测试命名 `*.test.tsx`，后端测试命名 `test_*.py`，涉及数据库操作时使用临时 SQLite，避免污染仓库中的演示数据库。

## Commit & Pull Request Guidelines
- 提交信息保持动词开头的简洁中文或英文，例如 `修复: 初始化 UV 虚拟环境`，单次提交聚焦单一改动。
- 分支从 `main` 派生 `feature/<scope>` 或 `fix/<scope>`，推送前执行 rebase 保持线性历史。
- Pull Request 需包含问题背景、解决方案与验证步骤；UI 改动附前后对比截图，接口变更同步更新 `docs/`，并确保通过 Lint 与测试。

## Security & Configuration Tips
- 开发环境变量维护在 `.env`，生产密钥交由部署平台管理，更新时同步 `.env.sample`。
- 锁定依赖于 `package-lock.json` 与 `uv.lock`；升级核心依赖需验证兼容性并记录在 PR。
- 仓库附带的 `app.db*` 仅作演示，禁止提交含真实数据的数据库文件，必要时在 `.gitignore` 中扩展排除项。
