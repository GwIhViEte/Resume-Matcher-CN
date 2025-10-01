# Repository Guidelines

## 项目结构与模块组织
- **apps/frontend/**：Next.js 前端应用，`app/` 存页面，`components/` 存通用 UI，公共 Hook 位于 `hooks/`，静态资源集中在 `public/`，样式配置见 `tailwind.config.js`。
- **apps/backend/**：FastAPI 服务，业务逻辑按 `core/`、`services/`、`models/`、`schemas/` 划分，入口为 `app/main.py`，默认 SQLite 文件位于仓库下的 `apps/backend/app.db*`。
- **docs/** 与 **assets/**：分别存放说明文档与媒体资源；自动化脚本和安装流程集中在根目录的 `setup.sh`、`setup.ps1`、`Makefile`。

## 构建、测试与开发命令
- **环境安装**：`npm install` 安装前端依赖；`npm run install:backend` 借助 `uv` 创建虚拟环境并安装后端；`make setup` 统一执行安装脚本。
- **本地开发**：`npm run dev` 并行启动前后端；仅调试单侧时分别运行 `npm run dev:frontend` 或 `npm run dev:backend`。
- **构建与发布**：`npm run build` 产出前端构建并触发后端检查；`make run-prod` 顺序执行构建并以生产模式启动。
- **清理提示**：`make clean` 目前仅输出需手工删除的目录，执行前确认目标避免误删。

## 编码风格与命名约定
- **格式化**：遵循 `.editorconfig`，全局两空格缩进、LF 行尾、UTF-8 编码，提交前去除尾随空白并保留文件收尾换行。
- **前端约定**：TypeScript 组件使用 PascalCase 命名，Hook 以 `use` 前缀；运行 `npm run lint` 触发 ESLint，Tailwind 工具类按布局→颜色→状态排序。
- **后端约定**：FastAPI 路由置于 `app/api`，Pydantic 模型以 `*Schema` 结尾，服务类以 `*Service` 命名，数据访问集中在 `app/services`，避免跨层直接耦合。

## 测试规范
- **现状与目标**：仓库暂未收录自动化测试；新增功能需配套测试覆盖关键匹配逻辑与 API。
- **前端测试**：建议在 `apps/frontend/__tests__/` 使用 Vitest 或 Playwright，文件命名 `*.test.tsx`，快照存于同级 `__snapshots__`。
- **后端测试**：采用 `pytest` 并放置在 `apps/backend/tests/`，命名 `test_*.py`，利用 FastAPI `TestClient` 构造请求，对 SQLite 操作使用临时数据库隔离。
- **覆盖要求**：关键流程维持 80% 覆盖率，提交前运行 `pytest` 与 `npm run test`（如定义）并在 PR 中附执行结果。

## 提交与 Pull Request 指南
- **提交信息**：保持动词开头的简洁中文或英文描述，例如 `修复: 初始化 UV 虚拟环境`，一次提交聚焦单一改动，必要时拆分前后端。
- **分支策略**：从 `main` 切出 `feature/<scope>` 或 `fix/<scope>` 分支，推送前执行 rebase 保持线性历史。
- **PR 要求**：说明问题背景、解决方案与验证步骤，关联 Issue；涉及 UI 需附前后对比截图，接口变更同步更新 `docs/`。
- **评审清单**：确保通过 Lint 与测试、无调试日志、配置文件不含敏感信息；数据库或脚本迁移需说明回滚策略。

## 安全与配置提示
- **环境变量**：开发配置存放于 `.env`，生产密钥使用部署平台管理；更新键值时同步维护 `.env.sample`。
- **依赖管理**：前端锁定于 `package-lock.json`，后端锁定于 `uv.lock`；升级核心依赖须验证匹配模型兼容并记录在 PR。
- **数据文件**：仓库包含演示用 `app.db*`，提交前勿上传含真实候选人数据的数据库文件，必要时在 `.gitignore` 中新增排除。
