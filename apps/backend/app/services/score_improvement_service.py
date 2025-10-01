import asyncio
import gc
import json
import logging
from datetime import datetime, timezone
from typing import AsyncGenerator, Dict, Optional, Tuple

import markdown
import numpy as np
from fastapi import HTTPException, status
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.agent import AgentManager, EmbeddingManager
from app.i18n import DEFAULT_LOCALE, get_target_language, normalize_locale, translate
from app.models import Job, ProcessedJob, ProcessedResume, Resume, Token
from app.schemas.json import json_schema_factory
from app.schemas.pydantic import ResumePreviewerModel
from .exceptions import (
	JobKeywordExtractionError,
	JobNotFoundError,
	JobParsingError,
	ResumeKeywordExtractionError,
	ResumeNotFoundError,
	ResumeParsingError,
)

logger = logging.getLogger(__name__)


class ScoreImprovementService:
	def __init__(self, db: AsyncSession, locale: str = DEFAULT_LOCALE, max_retries: int = 5):
		self.db = db
		self.locale = normalize_locale(locale)
		self.max_retries = max_retries
		self.md_agent_manager = AgentManager(strategy='md')
		self.json_agent_manager = AgentManager()
		self.embedding_manager = EmbeddingManager()

	def _t(self, key: str, **kwargs: object) -> str:
		return translate(key, self.locale, **kwargs)

	def _extract_keywords(self, raw_payload: Optional[str], *, entity: str) -> list[str]:
		if not raw_payload:
			return []

		try:
			parsed = json.loads(raw_payload)
		except json.JSONDecodeError as exc:
			logger.warning("Failed to decode %s keywords payload: %s", entity, exc)
			return []

		keywords: list[str] = []
		candidate: object = parsed

		if isinstance(parsed, dict):
			candidate = (
				parsed.get('extracted_keywords')
				or parsed.get('keywords')
				or parsed.get(f'{entity}_keywords')
			)
		elif isinstance(parsed, list):
			candidate = parsed

		if isinstance(candidate, dict):
			candidate = candidate.get('keywords') or candidate.get('values')

		if isinstance(candidate, list):
			keywords = [kw.strip() for kw in candidate if isinstance(kw, str) and kw.strip()]
		else:
			logger.warning("Unexpected %s keywords structure: %s", entity, type(candidate).__name__)

		return keywords

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

	def _validate_resume_keywords(self, processed_resume: ProcessedResume, resume_id: str) -> None:
		keywords = self._extract_keywords(processed_resume.extracted_keywords, entity='resume')
		if not keywords:
			raise ResumeKeywordExtractionError(resume_id=resume_id)

	def _validate_job_keywords(self, processed_job: ProcessedJob, job_id: str) -> None:
		keywords = self._extract_keywords(processed_job.extracted_keywords, entity='job')
		if not keywords:
			raise JobKeywordExtractionError(job_id=job_id)

	async def _get_resume(self, resume_id: str) -> Tuple[Resume, ProcessedResume]:
		resume_result = await self.db.execute(select(Resume).where(Resume.resume_id == resume_id))
		resume = resume_result.scalars().first()
		if not resume:
			raise ResumeNotFoundError(message=self._t('errors.resume.not_found', resume_id=resume_id))

		processed_resume_result = await self.db.execute(select(ProcessedResume).where(ProcessedResume.resume_id == resume_id))
		processed_resume = processed_resume_result.scalars().first()
		if not processed_resume:
			raise ResumeParsingError(message=self._t('errors.resume.parsing_failed', resume_id=resume_id))

		self._validate_resume_keywords(processed_resume, resume_id)
		return resume, processed_resume

	async def _get_job(self, job_id: str) -> Tuple[Job, ProcessedJob]:
		job_result = await self.db.execute(select(Job).where(Job.job_id == job_id))
		job = job_result.scalars().first()
		if not job:
			raise JobNotFoundError(message=self._t('errors.job.not_found', job_id=job_id))

		processed_job_result = await self.db.execute(select(ProcessedJob).where(ProcessedJob.job_id == job_id))
		processed_job = processed_job_result.scalars().first()
		if not processed_job:
			raise JobParsingError(message=self._t('errors.job.parsing_failed', job_id=job_id))

		self._validate_job_keywords(processed_job, job_id)
		return job, processed_job

	@staticmethod
	def calculate_cosine_similarity(embedding1: np.ndarray, embedding2: np.ndarray) -> float:
		if embedding1 is None or embedding2 is None:
			return 0.0

		vec1 = np.asarray(embedding1).squeeze()
		vec2 = np.asarray(embedding2).squeeze()

		if np.linalg.norm(vec1) == 0 or np.linalg.norm(vec2) == 0:
			return 0.0

		return float(np.dot(vec1, vec2) / (np.linalg.norm(vec1) * np.linalg.norm(vec2)))

	async def improve_score_with_llm(
		self,
		resume: str,
		extracted_resume_keywords: str,
		job: str,
		extracted_job_keywords: str,
		previous_cosine_similarity_score: float,
		extracted_job_keywords_embedding,
		model: str,
		token: Optional[str],
	) -> Tuple[str, float]:
		target_language = get_target_language(self.locale)
		prompt = translate(
			'prompts.resume_improvement',
			self.locale,
			current_score=previous_cosine_similarity_score,
			job=job,
			job_keywords=extracted_job_keywords,
			resume=resume,
			resume_keywords=extracted_resume_keywords,
			target_language=target_language,
		)

		updated_resume = await self.md_agent_manager.run(prompt=prompt, model=model, token=token)

		resume_embedding, updated_keywords_embedding = await asyncio.gather(
			self.embedding_manager.embed(updated_resume),
			self.embedding_manager.embed(extracted_job_keywords),
		)

		updated_score = self.calculate_cosine_similarity(updated_keywords_embedding, resume_embedding)
		return updated_resume, updated_score

	async def get_resume_for_previewer(self, updated_resume: str, model: str) -> Optional[Dict]:
		prompt = translate(
			'prompts.resume_preview',
			self.locale,
			schema=json.dumps(json_schema_factory.get('resume_preview'), indent=2),
			resume=updated_resume,
		)
		raw_output = await self.json_agent_manager.run(prompt=prompt, model=model)

		try:
			resume_preview: ResumePreviewerModel = ResumePreviewerModel.model_validate(raw_output)
			markdown_source = resume_preview.content or ''
			markdown_content = markdown.markdown(markdown_source)
			resume_preview.content_html = markdown_content
			return resume_preview.model_dump()
		except ValidationError as exc:
			logger.error("Validation error for resume preview: %s", exc)
			return None

	async def get_analysis_details(
		self,
		original_resume: str,
		improved_resume: str,
		job_description: str,
		original_score: float,
		new_score: float,
		model: str,
	) -> Dict:
		prompt_template = translate(
			'prompts.analysis',
			self.locale,
			target_language=get_target_language(self.locale),
			original_score=original_score,
			new_score=new_score,
			original_resume=original_resume,
			improved_resume=improved_resume,
			job_description=job_description,
		)

		try:
			analysis_output = await self.json_agent_manager.run(prompt=prompt_template, model=model)
			return {
				"details": analysis_output.get("details", ""),
				"commentary": analysis_output.get("commentary", ""),
				"improvements": analysis_output.get("improvements", []),
			}
		except Exception as exc:  # noqa: BLE001
			logger.error("Failed to generate analysis details: %s", exc)
			return {
				"details": self._t('analysis.fallback_details'),
				"commentary": self._t('analysis.fallback_commentary'),
				"improvements": self._t('analysis.fallback_improvements'),
			}

	async def run(self, resume_id: str, job_id: str, model: str = 'gpt-3.5-turbo', token: Optional[str] = None) -> Dict:
		resume, processed_resume = await self._get_resume(resume_id)
		job, processed_job = await self._get_job(job_id)

		extracted_job_keywords_list = self._extract_keywords(processed_job.extracted_keywords, entity='job')
		extracted_resume_keywords_list = self._extract_keywords(processed_resume.extracted_keywords, entity='resume')

		extracted_job_keywords = ', '.join(extracted_job_keywords_list)
		extracted_resume_keywords = ', '.join(extracted_resume_keywords_list)

		resume_embedding, job_kw_embedding = await asyncio.gather(
			self.embedding_manager.embed(resume.content),
			self.embedding_manager.embed(extracted_job_keywords),
		)

		cosine_similarity_score = self.calculate_cosine_similarity(job_kw_embedding, resume_embedding)

		updated_resume, updated_score = await self.improve_score_with_llm(
			resume=resume.content,
			extracted_resume_keywords=extracted_resume_keywords,
			job=job.content,
			extracted_job_keywords=extracted_job_keywords,
			previous_cosine_similarity_score=cosine_similarity_score,
			extracted_job_keywords_embedding=job_kw_embedding,
			model=model,
			token=token,
		)

		resume_preview, analysis_details = await asyncio.gather(
			self.get_resume_for_previewer(updated_resume=updated_resume, model=model),
			self.get_analysis_details(
				original_resume=resume.content,
				improved_resume=updated_resume,
				job_description=job.content,
				original_score=cosine_similarity_score,
				new_score=updated_score,
				model=model,
			),
		)

		logger.info("Resume Preview generated: %s", 'Yes' if resume_preview else 'No')
		logger.info("Analysis Details generated: %s", analysis_details)

		execution = {
			"resume_id": resume_id,
			"job_id": job_id,
			"original_score": cosine_similarity_score,
			"new_score": updated_score,
			"resume_preview": resume_preview,
			**analysis_details,
		}

		gc.collect()
		return execution

	async def run_and_stream(self, resume_id: str, job_id: str, model: str, token: Optional[str]) -> AsyncGenerator[str, None]:
		yield f"data: {json.dumps({'status': 'starting', 'message': self._t('analysis.stream_start')})}\n\n"
		result = await self.run(resume_id, job_id, model, token)
		yield f"data: {json.dumps({'status': 'completed', 'result': result, 'message': self._t('analysis.stream_complete')})}\n\n"
