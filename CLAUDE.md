# Using Gemini CLI for Large Codebase Analysis

@gemini-usage.md

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Resume-Matcher-CN is a Chinese-localized version of resume-matcher, a full-stack application that uses AI to match resumes against job descriptions and provide improvement suggestions. The project features a FastAPI backend with SQLAlchemy ORM and a Next.js frontend with TypeScript and Tailwind CSS.

## Architecture

### Backend (`apps/backend/`)
- **FastAPI** application with async support (Python 3.12+)
- **SQLAlchemy** with async SQLite database (`aiosqlite`)
- **Agent-based AI** system supporting multiple providers (OpenAI, Ollama)
- **Service layer** pattern: `resume_service.py`, `job_service.py`, `score_improvement_service.py`
- **Pydantic** schemas for request/response validation
- **Structured prompts** for AI interactions in `/prompt/` directory

### Frontend (`apps/frontend/`)
- **Next.js 15** with App Router and Turbopack
- **React 19** with TypeScript
- **Tailwind CSS v4** with custom UI components
- **Radix UI** primitives for accessible components
- **File upload** functionality with drag-and-drop support

## Common Development Commands

### Setup and Installation
```bash
# Windows (PowerShell) - includes Chinese mirrors for faster downloads
.\setup.ps1                    # Complete setup with dependencies
.\setup.ps1 -StartDev         # Setup and start development server

# Linux/macOS
./setup.sh                    # Complete setup
./setup.sh --start-dev        # Setup and start development server
```

### Development
```bash
# Start both frontend and backend in development mode
npm run dev

# Start services individually
npm run dev:frontend         # Next.js dev server with turbopack
npm run dev:backend          # FastAPI with uvicorn auto-reload

# Install dependencies
npm run install:frontend
npm run install:backend
npm install                  # Root dependencies + both apps
```

### Build and Production
```bash
npm run build               # Build both frontend and backend
npm run build:frontend      # Next.js production build
npm start                  # Start production servers
```

### Code Quality
```bash
npm run lint               # ESLint on frontend
cd apps/frontend && npm run format  # Prettier formatting
```

## Development Environment

### Required Tools
- **Node.js** ≥18 (with npm)
- **Python** ≥3.12 (with pip)
- **uv** (Python package manager, auto-installed by setup scripts)

### Environment Files
The setup scripts automatically create:
- `./.env` (from `.env.example`) - Root configuration
- `apps/backend/.env` (from `.env.sample`) - Backend configuration including API keys
- `apps/frontend/.env` (from `.env.sample`) - Frontend configuration

### Key Environment Variables
- `OPENAI_API_KEY` - Required for OpenAI provider
- `NEXT_PUBLIC_API_URL` - Frontend API endpoint (default: `http://localhost:8000`)
- `SYNC_DATABASE_URL` / `ASYNC_DATABASE_URL` - Database connections

## AI Provider Configuration

The application supports multiple AI providers through the agent system:
- **OpenAI** (`apps/backend/app/agent/providers/openai.py`)
- **Ollama** (`apps/backend/app/agent/providers/ollama.py`) - Uses `gemma3:4b` model
- Provider selection is configurable per request

## Code Organization Patterns

### Backend Structure
- **Models**: SQLAlchemy ORM models in `app/models/`
- **Schemas**: Pydantic models split into JSON schemas (`schemas/json/`) and API schemas (`schemas/pydantic/`)
- **Services**: Business logic layer handling AI interactions and data processing
- **API Routes**: Versioned routes in `app/api/router/v1/`
- **Prompts**: Structured AI prompts in `app/prompt/`

### Frontend Structure
- **App Router**: Routes in `app/(default)/`
- **Components**: Reusable UI components in `components/ui/` and `components/common/`
- **Hooks**: Custom React hooks in `hooks/`
- **Utils**: Utility functions in `lib/utils.ts`

## Testing and Validation

The project uses:
- **ESLint** for code linting (frontend)
- **Prettier** for code formatting (frontend)
- **TypeScript** strict mode for type checking
- **Pydantic** for runtime data validation (backend)

Always run `npm run lint` before committing frontend changes.

## Database and Migrations

- Uses **SQLite** with async support via `aiosqlite`
- Database models are in `apps/backend/app/models/`
- No explicit migration system; relies on SQLAlchemy's create_all() for development

## Chinese Localization Features

This fork includes:
- Complete Chinese UI translation
- Mandatory/optional field indicators for resume uploads
- Chinese-optimized AI prompts and responses
- Domestic mirror support for faster dependency installation (setup scripts)