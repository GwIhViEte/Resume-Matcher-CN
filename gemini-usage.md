# 使用 Gemini CLI 进行大型代码库分析

当分析可能超出上下文限制的大型代码库或多个文件时，请使用 Gemini CLI 及其巨大的上下文窗口。使用 `gemini -p` 来利用 Google Gemini 的大上下文容量。

## 文件和目录包含语法

使用 `@` 语法在 Gemini 提示中包含文件和目录。路径应相对于你运行 gemini 命令的位置：

### 示例：

**单文件分析：**
```bash
gemini -p "@src/main.py 解释这个文件的用途和结构"
```

多个文件：
```bash
gemini -p "@package.json @src/index.js 分析代码中使用的依赖"
```

整个目录：
```bash
gemini -p "@src/ 总结这个代码库的架构"
```

多个目录：
```bash
gemini -p "@src/ @tests/ 分析源代码的测试覆盖率"
```

当前目录和子目录：
```bash
gemini -p "@./ 给我这个整个项目的概览"
```

或使用 --all_files 标志：
```bash
gemini --all_files -p "分析项目结构和依赖"
```

## 实现验证示例

检查功能是否已实现：
```bash
gemini -p "@src/ @lib/ 此代码库中是否实现了暗黑模式？显示相关文件和函数"
```

验证身份验证实现：
```bash
gemini -p "@src/ @middleware/ 是否实现了 JWT 身份验证？列出所有身份验证相关的端点和中间件"
```

检查特定模式：
```bash
gemini -p "@src/ 是否有处理 WebSocket 连接的 React hooks？列出它们及其文件路径"
```

验证错误处理：
```bash
gemini -p "@src/ @api/ 是否为所有 API 端点实现了适当的错误处理？显示 try-catch 块的示例"
```

检查速率限制：
```bash
gemini -p "@backend/ @middleware/ API 是否实现了速率限制？显示实现细节"
```

验证缓存策略：
```bash
gemini -p "@src/ @lib/ @services/ 是否实现了 Redis 缓存？列出所有缓存相关函数及其用法"
```

检查特定安全措施：
```bash
gemini -p "@src/ @api/ 是否实现了 SQL 注入保护？显示用户输入是如何被清理的"
```

验证功能的测试覆盖率：
```bash
gemini -p "@src/payment/ @tests/ 支付处理模块是否经过了完整测试？列出所有测试用例"
```

## 何时使用 Gemini CLI

在以下情况下使用 gemini -p：
- 分析整个代码库或大型目录
- 比较多个大型文件
- 需要理解项目范围的模式或架构
- 当前上下文窗口不足以完成任务
- 处理总计超过 100KB 的文件
- 验证特定功能、模式或安全措施是否已实现
- 检查整个代码库中是否存在某些编码模式

## 重要说明

- @ 语法中的路径相对于调用 gemini 时的当前工作目录
- CLI 会将文件内容直接包含在上下文中
- 只读分析不需要 --yolo 标志
- Gemini 的上下文窗口可以处理会溢出 Claude 上下文的整个代码库
- 检查实现时，具体说明你要查找的内容以获得准确结果