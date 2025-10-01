### **Windows 安装与使用指南 / Windows Setup & Usage Guide**

---

#### **系统要求 / Prerequisites**

**中文**
- Windows 10/11，PowerShell 5.1 或更高
- Node.js v18+（含 npm）
- Python 3.9+（建议 3.12，与仓库默认一致）
- UV 包管理器（脚本会尝试自动安装）

**English**
- Windows 10/11, PowerShell 5.1 or higher
- Node.js v18+ (including npm)
- Python 3.9+ (3.12 is recommended, consistent with the repository's default)
- UV package manager (the script will attempt to install it automatically)

---

### **一、克隆仓库 / I. Clone the Repository**

**中文**
```bash
git clone https://github.com/GwIhViEte/Resume-Matcher-CN.git
cd Resume-Matcher-CN
```

**English**
```bash
git clone https://github.com/GwIhViEte/Resume-Matcher-CN.git
cd Resume-Matcher-CN
```

---

### **二、运行一键脚本 / II. Run the One-Click Script**

**中文**
脚本会自动检测国内镜像可用性，默认选择对应源并输出相应语言提示。

```powershell
./setup.ps1
```

- 若希望强制使用中文提示 + 国内镜像：`./setup.ps1 -NetworkProfile china`
- 若希望强制使用英语提示 + 官方源：`./setup.ps1 -NetworkProfile global`
- 可附加 `-StartDev` 在依赖安装完成后直接执行 `npm run dev`。

**脚本执行内容：**
1. 检查 Node/npm/Python/pip/uv，并按需安装 uv
2. 根据网络模式设置 npm、PyPI、uv 的下载源
3. 复制根目录、后端、前端的 .env 示例文件
4. 在后端创建虚拟环境，自动同步依赖（含 python-docx、pdfplumber 等）
如果后端报错，尝试使用
```bash
cd apps/backend
uv sync
cd ../..
```
安装`python-docx`、`pdfplumber`依赖
5. 安装前端依赖

**English**
The script auto-detects whether Chinese mirrors are reachable and switches both registry and language accordingly.

```powershell
./setup.ps1
```

- To force Chinese prompts + Chinese mirrors: `./setup.ps1 -NetworkProfile china`
- To force English prompts + official sources: `./setup.ps1 -NetworkProfile global`
- You can append `-StartDev` to execute `npm run dev` immediately after dependencies are installed.

**What the script does:**
1. Checks for Node/npm/Python/pip/uv, and installs uv if needed.
2. Sets the download sources for npm, PyPI, and uv based on the network profile.
3. Copies the `.env` example files for the root directory, backend, and frontend.
4. Creates a virtual environment in the backend and automatically syncs dependencies (including `python-docx`, `pdfplumber`, etc.).
5. Installs frontend dependencies.

---

### **三、配置环境变量 / III. Configure Environment Variables**

**中文**
脚本会生成 `.env`、`apps/backend/.env`、`apps/frontend/.env` 三个文件。
请打开这些文件，至少设置以下值：

- `OPENAI_API_KEY`（或其他兼容 LLM 服务的密钥）
- 如果使用自建模型或代理，还需调整 `LLM_BASE_URL` 等配置
- 前端 .env 中的 API 地址保持与本地后端一致（默认 `http://127.0.0.1:8000`）

**English**
The script will generate three files: `.env`, `apps/backend/.env`, and `apps/frontend/.env`.
Please open these files and set at least the following values:

- `OPENAI_API_KEY` (or an API key for another compatible LLM service)
- If you are using a self-hosted model or a proxy, you will also need to adjust configurations like `LLM_BASE_URL`.
- The API address in the frontend `.env` file should match the local backend (default is `http://127.0.0.1:8000`).

---

### **四、启动开发环境 / IV. Start the Development Servers**

**中文**
若未在步骤二中使用 `-StartDev`，执行：
```bash
npm run dev
```

- 后端默认监听 `http://127.0.0.1:8000`
- 前端默认监听 `http://localhost:3000` (支持局域网访问)

如需仅启动单端，可分别执行：
```bash
npm run dev:backend
npm run dev:frontend
```

**English**
If you did not use `-StartDev` in step two, execute:
```bash
npm run dev
```

- The backend listens on `http://127.0.0.1:8000` by default.
- The frontend listens on `http://localhost:3000` by default (accessible on the local network).

To start only the backend or frontend, you can execute them separately:
```bash
npm run dev:backend
npm run dev:frontend
```

---

### **五、验证与常见操作 / V. Verify & Tips**

**中文**
1. 浏览器访问 `http://localhost:3000`，确认界面能在中文/英文之间切换；上传简历、粘贴职位描述完成一次匹配流程。
2. 若网络环境变化，可再次运行 `setup.ps1 -NetworkProfile china|global` 调整镜像与提示语言。
3. 脚本和依赖更新后，如遇 Python 虚拟环境缺少最新包，可在 `apps/backend` 内运行 `uv sync` 补齐。
4. 需要停用开发服务时，按 `Ctrl + C` 结束对应 npm 命令。

**English**
1. Open your browser and navigate to `http://localhost:3000`. Confirm that the interface can switch between Chinese and English. Complete a matching process by uploading a resume and pasting a job description.
2. If your network environment changes, you can run `setup.ps1 -NetworkProfile china|global` again to adjust the mirrors and prompt language.
3. After updating the script and dependencies, if the Python virtual environment is missing the latest packages, you can run `uv sync` inside the `apps/backend` directory to update them.
4. To stop the development servers, press `Ctrl + C` in the terminal where the npm command is running.

---

**中文**
完成！祝你使用顺利。

**English**
Done! We wish you a smooth experience.
