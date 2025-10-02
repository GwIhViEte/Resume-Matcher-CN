import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import HTTPException, status
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.agent import AgentManager
from app.i18n import DEFAULT_LOCALE, normalize_locale, translate
from app.models import Job, ProcessedJob, Resume, Token
from app.prompt import prompt_factory
from app.schemas.json import json_schema_factory
from app.schemas.pydantic import StructuredJobModel
from .exceptions import JobNotFoundError

logger = logging.getLogger(__name__)

PREMIUM_MODELS = ['gpt']


class JobService:

	def __init__(self, db: AsyncSession, locale: str = DEFAULT_LOCALE):
		self.db = db
		self.locale = normalize_locale(locale)
		self.json_agent_manager = AgentManager()

	def _t(self, key: str, **kwargs: object) -> str:
		return translate(key, self.locale, **kwargs)

	async def _validate_token(self, token_str: Optional[str]) -> bool:
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

	async def create_and_store_job(self, job_data: dict) -> List[str]:
		resume_id = str(job_data.get('resume_id'))
		model = job_data.get('model', 'gpt-3.5-turbo')
		token = job_data.get('token')

		if not await self._is_resume_available(resume_id):
			raise HTTPException(
				status_code=status.HTTP_400_BAD_REQUEST,
				detail=self._t('errors.resume.not_found', resume_id=resume_id),
			)

		if model in PREMIUM_MODELS:
			is_valid_token = await self._validate_token(token)
			if not is_valid_token:
				raise HTTPException(
					status_code=status.HTTP_401_UNAUTHORIZED,
					detail=self._t('errors.auth.invalid_token'),
				)

		job_ids: List[str] = []
		for description in job_data.get('job_descriptions', []):
			job_id = str(uuid.uuid4())
			job = Job(
				job_id=job_id,
				resume_id=str(resume_id),
				content=description,
			)
			self.db.add(job)

			await self._extract_and_store_structured_job(job_id=job_id, job_description_text=description, model=model)
			logger.info("Job ID: %s", job_id)
			job_ids.append(job_id)

		await self.db.commit()
		return job_ids

	async def _is_resume_available(self, resume_id: str) -> bool:
		query = select(Resume).where(Resume.resume_id == resume_id)
		result = await self.db.scalar(query)
		return result is not None

	async def _extract_and_store_structured_job(self, job_id: str, job_description_text: str, model: str) -> None:
		structured_job = await self._extract_structured_json(job_description_text, model=model)
		if not structured_job:
			logger.info("Structured job extraction failed.")
			return

		processed_job = ProcessedJob(
			job_id=job_id,
			job_title=structured_job.get('job_title'),
			company_profile=json.dumps(structured_job.get('company_profile')) if structured_job.get('company_profile') else None,
			location=json.dumps(structured_job.get('location')) if structured_job.get('location') else None,
			date_posted=structured_job.get('date_posted'),
			employment_type=structured_job.get('employment_type'),
			job_summary=structured_job.get('job_summary'),
			key_responsibilities=json.dumps({"key_responsibilities": structured_job.get('key_responsibilities', [])}) if structured_job.get('key_responsibilities') else None,
			qualifications=json.dumps(structured_job.get('qualifications', [])) if structured_job.get('qualifications') else None,
			compensation_and_benfits=json.dumps(structured_job.get('compensation_and_benfits', [])) if structured_job.get('compensation_and_benfits') else None,
			application_info=json.dumps(structured_job.get('application_info', [])) if structured_job.get('application_info') else None,
			extracted_keywords=json.dumps({"extracted_keywords": structured_job.get('extracted_keywords', [])}) if structured_job.get('extracted_keywords') else None,
		)

		self.db.add(processed_job)
		await self.db.flush()

	async def _extract_structured_json(self, job_description_text: str, model: str) -> Optional[Dict[str, Any]]:
		prompt_template = prompt_factory.get('structured_job', self.locale)
		prompt = prompt_template.format(
			json.dumps(json_schema_factory.get('structured_job'), indent=2),
			job_description_text,
		)
		logger.info("Structured Job Prompt: %s", prompt)
		raw_output = await self.json_agent_manager.run(prompt=prompt, model=model)

		try:
			structured_job: StructuredJobModel = StructuredJobModel.model_validate(raw_output)
			return structured_job.model_dump(mode='json')
		except ValidationError as exc:
			logger.info("Validation error: %s", exc)
			return None

	async def get_job_with_processed_data(self, job_id: str) -> Optional[Dict]:
		job_query = select(Job).where(Job.job_id == job_id)
		job_result = await self.db.execute(job_query)
		job = job_result.scalars().first()

		if not job:
			raise JobNotFoundError(message=self._t('errors.job.not_found', job_id=job_id))

		processed_query = select(ProcessedJob).where(ProcessedJob.job_id == job_id)
		processed_result = await self.db.execute(processed_query)
		processed_job = processed_result.scalars().first()

		combined_data: Dict[str, Any] = {
			"job_id": job.job_id,
			"raw_job": {
				"id": job.id,
				"resume_id": job.resume_id,
				"content": job.content,
				"created_at": job.created_at.isoformat() if job.created_at else None,
			},
			"processed_job": None,
		}

		if processed_job:
			combined_data["processed_job"] = {
				"job_title": processed_job.job_title,
				"company_profile": json.loads(processed_job.company_profile) if processed_job.company_profile else None,
				"location": json.loads(processed_job.location) if processed_job.location else None,
				"date_posted": processed_job.date_posted,
				"employment_type": processed_job.employment_type,
				"job_summary": processed_job.job_summary,
				"key_responsibilities": _load_nested_list(processed_job.key_responsibilities, 'key_responsibilities'),
				"qualifications": _load_nested_list(processed_job.qualifications, 'qualifications'),
				"compensation_and_benfits": _load_nested_list(processed_job.compensation_and_benfits, 'compensation_and_benfits'),
				"application_info": _load_nested_list(processed_job.application_info, 'application_info'),
				"extracted_keywords": _load_nested_list(processed_job.extracted_keywords, 'extracted_keywords'),
				"processed_at": processed_job.processed_at.isoformat() if processed_job.processed_at else None,
			}

		return combined_data


def _load_nested_list(raw: Optional[str], key: str) -> Optional[List[Any]]:
	if not raw:
		return None
	try:
		return json.loads(raw).get(key, [])
	except json.JSONDecodeError:
		logger.error("Failed to load nested list for key %s", key)
		return None

