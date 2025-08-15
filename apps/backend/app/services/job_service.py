import uuid
import json
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone

from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status

from app.agent import AgentManager
from app.prompt import prompt_factory
from app.schemas.json import json_schema_factory
from app.models import Job, Resume, ProcessedJob, Token
from app.schemas.pydantic import StructuredJobModel
from .exceptions import JobNotFoundError

logger = logging.getLogger(__name__)


class JobService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.json_agent_manager = AgentManager()

    async def _validate_token(self, token_str: str) -> bool:
        if not token_str:
            return False
        
        # --- 关键修改：只验证，不设为无效 ---
        query = select(Token).where(
            Token.token == token_str, 
            Token.is_valid == True,
            Token.expires_at > datetime.now(timezone.utc)
        )
        result = await self.db.execute(query)
        token = result.scalars().first()
        
        return token is not None

    async def create_and_store_job(self, job_data: dict) -> List[str]:
        resume_id = str(job_data.get("resume_id"))
        model = job_data.get("model", "gpt-3.5-turbo")
        token = job_data.get("token")

        if not await self._is_resume_available(resume_id):
            raise AssertionError(
                f"resume corresponding to resume_id: {resume_id} not found"
            )

        if model in ["gpt-5", "gpt-4o"]:
            # --- 关键修改：调用只验证的函数 ---
            is_valid_token = await self._validate_token(token)
            if not is_valid_token:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="高级模型的Token无效、过期或丢失",
                )

        job_ids = []
        for job_description in job_data.get("job_descriptions", []):
            job_id = str(uuid.uuid4())
            job = Job(
                job_id=job_id,
                resume_id=str(resume_id),
                content=job_description,
            )
            self.db.add(job)

            await self._extract_and_store_structured_job(
                job_id=job_id, job_description_text=job_description, model=model
            )
            logger.info(f"Job ID: {job_id}")
            job_ids.append(job_id)

        await self.db.commit()
        return job_ids

    async def _is_resume_available(self, resume_id: str) -> bool:
        query = select(Resume).where(Resume.resume_id == resume_id)
        result = await self.db.scalar(query)
        return result is not None

    async def _extract_and_store_structured_job(
        self, job_id, job_description_text: str, model: str
    ):
        structured_job = await self._extract_structured_json(job_description_text, model=model)
        if not structured_job:
            logger.info("Structured job extraction failed.")
            return None

        processed_job = ProcessedJob(
            job_id=job_id,
            job_title=structured_job.get("job_title"),
            company_profile=json.dumps(structured_job.get("company_profile"))
            if structured_job.get("company_profile")
            else None,
            location=json.dumps(structured_job.get("location"))
            if structured_job.get("location")
            else None,
            date_posted=structured_job.get("date_posted"),
            employment_type=structured_job.get("employment_type"),
            job_summary=structured_job.get("job_summary"),
            key_responsibilities=json.dumps(
                {"key_responsibilities": structured_job.get("key_responsibilities", [])}
            )
            if structured_job.get("key_responsibilities")
            else None,
            qualifications=json.dumps(structured_job.get("qualifications", []))
            if structured_job.get("qualifications")
            else None,
            compensation_and_benfits=json.dumps(
                structured_job.get("compensation_and_benfits", [])
            )
            if structured_job.get("compensation_and_benfits")
            else None,
            application_info=json.dumps(structured_job.get("application_info", []))
            if structured_job.get("application_info")
            else None,
            extracted_keywords=json.dumps(
                {"extracted_keywords": structured_job.get("extracted_keywords", [])}
            )
            if structured_job.get("extracted_keywords")
            else None,
        )

        self.db.add(processed_job)
        await self.db.flush()
        return job_id

    async def _extract_structured_json(
        self, job_description_text: str, model: str
    ) -> Dict[str, Any] | None:
        prompt_template = prompt_factory.get("structured_job")
        prompt = prompt_template.format(
            json.dumps(json_schema_factory.get("structured_job"), indent=2),
            job_description_text,
        )
        logger.info(f"Structured Job Prompt: {prompt}")
        raw_output = await self.json_agent_manager.run(prompt=prompt, model=model)

        try:
            structured_job: StructuredJobModel = StructuredJobModel.model_validate(
                raw_output
            )
        except ValidationError as e:
            logger.info(f"Validation error: {e}")
            return None
        return structured_job.model_dump(mode="json")

    async def get_job_with_processed_data(self, job_id: str) -> Optional[Dict]:
        job_query = select(Job).where(Job.job_id == job_id)
        job_result = await self.db.execute(job_query)
        job = job_result.scalars().first()

        if not job:
            raise JobNotFoundError(job_id=job_id)

        processed_query = select(ProcessedJob).where(ProcessedJob.job_id == job_id)
        processed_result = await self.db.execute(processed_query)
        processed_job = processed_result.scalars().first()

        combined_data = {
            "job_id": job.job_id,
            "raw_job": {
                "id": job.id,
                "resume_id": job.resume_id,
                "content": job.content,
                "created_at": job.created_at.isoformat() if job.created_at else None,
            },
            "processed_job": None
        }

        if processed_job:
            combined_data["processed_job"] = {
                "job_title": processed_job.job_title,
                "company_profile": json.loads(processed_job.company_profile) if processed_job.company_profile else None,
                "location": json.loads(processed_job.location) if processed_job.location else None,
                "date_posted": processed_job.date_posted,
                "employment_type": processed_job.employment_type,
                "job_summary": processed_job.job_summary,
                "key_responsibilities": json.loads(processed_job.key_responsibilities).get("key_responsibilities", []) if processed_job.key_responsibilities else None,
                "qualifications": json.loads(processed_job.qualifications).get("qualifications", []) if processed_job.qualifications else None,
                "compensation_and_benfits": json.loads(processed_job.compensation_and_benfits).get("compensation_and_benfits", []) if processed_job.compensation_and_benfits else None,
                "application_info": json.loads(processed_job.application_info).get("application_info", []) if processed_job.application_info else None,
                "extracted_keywords": json.loads(processed_job.extracted_keywords).get("extracted_keywords", []) if processed_job.extracted_keywords else None,
                "processed_at": processed_job.processed_at.isoformat() if processed_job.processed_at else None,
            }

        return combined_data