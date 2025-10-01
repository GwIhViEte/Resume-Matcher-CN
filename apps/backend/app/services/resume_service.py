import json
import logging
import os
import tempfile
from datetime import datetime, timezone
from typing import Dict, Optional

import uuid

import docx
import pdfplumber
from fastapi import HTTPException, status
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.agent import AgentManager
from app.i18n import DEFAULT_LOCALE, normalize_locale, translate
from app.models import ProcessedResume, Resume, Token
from app.prompt import prompt_factory
from app.schemas.json import json_schema_factory
from app.schemas.pydantic import StructuredResumeModel
from .exceptions import ResumeNotFoundError, ResumeValidationError

logger = logging.getLogger(__name__)


class ResumeService:
	def __init__(self, db: AsyncSession, locale: str = DEFAULT_LOCALE):
		self.db = db
		self.locale = normalize_locale(locale)
		self.json_agent_manager = AgentManager()

	def _t(self, key: str, **kwargs: object) -> str:
		return translate(key, self.locale, **kwargs)

	def _extract_text_from_pdf(self, file_path: str) -> str:
		try:
			with pdfplumber.open(file_path) as pdf:
				text_parts = [page.extract_text() or '' for page in pdf.pages]
				return "\n".join(part for part in text_parts if part)
		except Exception as exc:  # noqa: BLE001
			logger.error("PDF extraction failed: %s", exc)
			raise ResumeValidationError(message=self._t('errors.resume.pdf_extract_failed', error=str(exc)))

	def _extract_text_from_docx(self, file_path: str) -> str:
		try:
			document = docx.Document(file_path)
			return "\n".join(paragraph.text for paragraph in document.paragraphs if paragraph.text.strip())
		except Exception as exc:  # noqa: BLE001
			logger.error("DOCX extraction failed: %s", exc)
			raise ResumeValidationError(message=self._t('errors.resume.docx_extract_failed', error=str(exc)))

	async def _validate_token(self, token_str: str | None) -> bool:
		if not token_str:
			return False

		query = select(Token).where(
			Token.token == token_str,
			Token.is_valid.is_(True),
			Token.expires_at > datetime.now(timezone.utc),
		)
		result = await self.db.execute(query)
		token = result.scalars().first()
		return token is not None

	async def convert_and_store_resume(
		self,
		file_bytes: bytes,
		file_type: str,
		filename: str,
		content_type: str = 'md',
		model: str = 'gpt-3.5-turbo',
		token: Optional[str] = None,
	):
		if model in PREMIUM_MODELS:
			is_valid_token = await self._validate_token(token)
			if not is_valid_token:
				raise HTTPException(
					status_code=status.HTTP_401_UNAUTHORIZED,
					detail=self._t('errors.auth.invalid_token'),
				)

		file_extension = self._get_file_extension(file_type)

		with tempfile.NamedTemporaryFile(delete=False, suffix=file_extension) as temp_file:
			temp_file.write(file_bytes)
			temp_path = temp_file.name

		try:
			if file_extension == '.pdf':
				text_content = self._extract_text_from_pdf(temp_path)
			elif file_extension == '.docx':
				text_content = self._extract_text_from_docx(temp_path)
			else:
				raise ResumeValidationError(message=self._t('errors.file.unsupported', file_type=file_type))

			if not text_content or not text_content.strip():
				raise ResumeValidationError(message=self._t('errors.resume.no_text'))

			try:
				resume_id = await self._store_resume_in_db(text_content, content_type)
				await self._extract_and_store_structured_resume(
					resume_id=resume_id,
					resume_text=text_content,
					model=model,
				)
				await self.db.commit()
				return resume_id
			except Exception:  # noqa: BLE001
				await self.db.rollback()
				raise
		finally:
			if os.path.exists(temp_path):
				try:
					os.remove(temp_path)
				except Exception as exc:  # noqa: BLE001
					logger.warning("Failed to remove temp file: %s", exc)

	def _get_file_extension(self, file_type: str) -> str:
		mime_to_ext = {
			"application/pdf": ".pdf",
			"application/vnd.openxmlformats-officedocument.wordprocessingml.document": ".docx",
		}
		return mime_to_ext.get(file_type, '')

	async def _store_resume_in_db(self, text_content: str, content_type: str) -> str:
		resume = Resume(
			resume_id=str(uuid.uuid4()),
			content=text_content,
			content_type=content_type,
		)
		self.db.add(resume)
		await self.db.flush()
		return resume.resume_id

	async def _extract_and_store_structured_resume(self, resume_id: str, resume_text: str, model: str) -> None:
		structured_resume = await self._extract_structured_json(resume_text, model)
		if not structured_resume:
			return

		try:
			processed_resume = ProcessedResume(
				resume_id=resume_id,
				personal_data=safe_json_dumps(structured_resume.get('personal_data')),
				experiences=safe_json_dumps(structured_resume.get('experiences', []), 'experiences'),
				projects=safe_json_dumps(structured_resume.get('projects', []), 'projects'),
				skills=safe_json_dumps(structured_resume.get('skills', []), 'skills'),
				research_work=safe_json_dumps(structured_resume.get('research_work', []), 'research_work'),
				achievements=safe_json_dumps(structured_resume.get('achievements', []), 'achievements'),
				education=safe_json_dumps(structured_resume.get('education', []), 'education'),
				extracted_keywords=safe_json_dumps(structured_resume.get('extracted_keywords', []), 'extracted_keywords'),
			)

			self.db.add(processed_resume)
			await self.db.flush()
		except ResumeValidationError:
			raise
		except Exception as exc:  # noqa: BLE001
			logger.error("Error storing structured resume: %s", exc)
			raise ResumeValidationError(
				resume_id=resume_id,
				message=self._t('errors.resume.store_structured_failed', error=str(exc)),
			)

	async def _extract_structured_json(self, resume_text: str, model: str) -> Optional[Dict]:
		prompt_template = prompt_factory.get('structured_resume', self.locale)
		prompt = prompt_template.format(
			json.dumps(json_schema_factory.get('structured_resume'), indent=2),
			resume_text,
		)
		logger.debug("Structured Resume Prompt: %s...", prompt[:500])

		raw_output = await self.json_agent_manager.run(prompt=prompt, model=model)

		try:
			structured_resume = StructuredResumeModel.model_validate(raw_output)
			return structured_resume.model_dump()
		except ValidationError as exc:
			logger.error("Validation error: %s", exc)
			error_details = []
			for error in exc.errors():
				field = ' -> '.join(str(loc) for loc in error['loc'])
				error_details.append(f"{field}: {error['msg']}")

			user_message = self._t('errors.resume.validation_failed', details='; '.join(error_details))
			raise ResumeValidationError(validation_error=user_message, message=user_message)

	async def get_resume_with_processed_data(self, resume_id: str) -> Optional[Dict]:
		resume_query = select(Resume).where(Resume.resume_id == resume_id)
		resume_result = await self.db.execute(resume_query)
		resume = resume_result.scalars().first()

		if not resume:
			raise ResumeNotFoundError(message=self._t('errors.resume.not_found', resume_id=resume_id))

		processed_query = select(ProcessedResume).where(ProcessedResume.resume_id == resume_id)
		processed_result = await self.db.execute(processed_query)
		processed_resume = processed_result.scalars().first()

		combined_data = {
			"resume_id": resume.resume_id,
			"raw_resume": {
				"id": resume.id,
				"content": resume.content,
				"content_type": resume.content_type,
				"created_at": resume.created_at.isoformat() if resume.created_at else None,
			},
			"processed_resume": None,
		}

		if processed_resume:
			combined_data["processed_resume"] = {
				"personal_data": safe_json_loads(processed_resume.personal_data),
				"experiences": safe_json_loads(processed_resume.experiences, "experiences"),
				"projects": safe_json_loads(processed_resume.projects, "projects"),
				"skills": safe_json_loads(processed_resume.skills, "skills"),
				"research_work": safe_json_loads(processed_resume.research_work, "research_work"),
				"achievements": safe_json_loads(processed_resume.achievements, "achievements"),
				"education": safe_json_loads(processed_resume.education, "education"),
				"extracted_keywords": safe_json_loads(processed_resume.extracted_keywords, "extracted_keywords"),
				"processed_at": processed_resume.processed_at.isoformat() if processed_resume.processed_at else None,
			}

		return combined_data


PREMIUM_MODELS = ['gpt-4o']


def safe_json_dumps(payload: object, key: str | None = None) -> str:
	if payload is None:
		return ''
	try:
		return json.dumps(payload)
	except (TypeError, ValueError) as exc:
		logger.error("Failed to dump JSON for %s: %s", key or 'payload', exc)
		return ''


def safe_json_loads(data: str, key: str | None = None) -> object:
	if not data:
		return [] if key else None
	try:
		parsed = json.loads(data)
		return parsed.get(key, []) if key else parsed
	except json.JSONDecodeError:
		logger.error("Failed to parse JSON for %s", key or 'payload')
		return [] if key else None
