import gc
import json
import asyncio
import logging
import markdown
import numpy as np

from fastapi import HTTPException, status
from sqlalchemy.future import select
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Dict, Optional, Tuple, AsyncGenerator

from app.prompt import prompt_factory
from app.schemas.json import json_schema_factory
from app.schemas.pydantic import ResumePreviewerModel
from app.agent import EmbeddingManager, AgentManager
from app.models import Resume, Job, ProcessedResume, ProcessedJob, Token
from .exceptions import (
    ResumeNotFoundError,
    JobNotFoundError,
    ResumeParsingError,
    JobParsingError,
    ResumeKeywordExtractionError,
    JobKeywordExtractionError,
)

logger = logging.getLogger(__name__)


class ScoreImprovementService:
    """
    Service to handle scoring of resumes and jobs using embeddings.
    Fetches Resume and Job data from the database, computes embeddings,
    and calculates cosine similarity scores. Uses LLM for iteratively improving
    the scoring process.
    """

    def __init__(self, db: AsyncSession, max_retries: int = 5):
        self.db = db
        self.max_retries = max_retries
        self.md_agent_manager = AgentManager(strategy="md")
        self.json_agent_manager = AgentManager()
        self.embedding_manager = EmbeddingManager()

    async def _validate_token(self, token_str: str) -> bool:
        if not token_str:
            return False
        
        query = select(Token).where(Token.token == token_str, Token.is_valid == True)
        result = await self.db.execute(query)
        token = result.scalars().first()
        
        return token is not None

    def _validate_resume_keywords(
        self, processed_resume: ProcessedResume, resume_id: str
    ) -> None:
        if not processed_resume.extracted_keywords:
            raise ResumeKeywordExtractionError(resume_id=resume_id)
        try:
            keywords_data = json.loads(processed_resume.extracted_keywords)
            if not keywords_data.get("extracted_keywords"):
                raise ResumeKeywordExtractionError(resume_id=resume_id)
        except (json.JSONDecodeError, AttributeError):
            raise ResumeKeywordExtractionError(resume_id=resume_id)

    def _validate_job_keywords(self, processed_job: ProcessedJob, job_id: str) -> None:
        if not processed_job.extracted_keywords:
            raise JobKeywordExtractionError(job_id=job_id)
        try:
            keywords_data = json.loads(processed_job.extracted_keywords)
            if not keywords_data.get("extracted_keywords"):
                raise JobKeywordExtractionError(job_id=job_id)
        except (json.JSONDecodeError, AttributeError):
            raise JobKeywordExtractionError(job_id=job_id)

    async def _get_resume(
        self, resume_id: str
    ) -> Tuple[Resume, ProcessedResume]:
        resume_result = await self.db.execute(select(Resume).where(Resume.resume_id == resume_id))
        resume = resume_result.scalars().first()
        if not resume:
            raise ResumeNotFoundError(resume_id=resume_id)

        processed_resume_result = await self.db.execute(select(ProcessedResume).where(ProcessedResume.resume_id == resume_id))
        processed_resume = processed_resume_result.scalars().first()
        if not processed_resume:
            raise ResumeParsingError(resume_id=resume_id)

        self._validate_resume_keywords(processed_resume, resume_id)
        return resume, processed_resume

    async def _get_job(self, job_id: str) -> Tuple[Job, ProcessedJob]:
        job_result = await self.db.execute(select(Job).where(Job.job_id == job_id))
        job = job_result.scalars().first()
        if not job:
            raise JobNotFoundError(job_id=job_id)

        processed_job_result = await self.db.execute(select(ProcessedJob).where(ProcessedJob.job_id == job_id))
        processed_job = processed_job_result.scalars().first()
        if not processed_job:
            raise JobParsingError(job_id=job_id)

        self._validate_job_keywords(processed_job, job_id)
        return job, processed_job

    def calculate_cosine_similarity(
        self,
        embedding1: np.ndarray,
        embedding2: np.ndarray,
    ) -> float:
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
        extracted_job_keywords_embedding: np.ndarray,
        model: str,
        token: Optional[str] = None,
    ) -> Tuple[str, float]:
    
        if model in ["gpt-4o"]:
            is_valid_token = await self._validate_token(token)
            if not is_valid_token:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid or missing token for premium model.",
                )

        prompt_template = prompt_factory.get("resume_improvement")
        best_resume, best_score = resume, previous_cosine_similarity_score

        for attempt in range(1, self.max_retries + 1):
            logger.info(f"Attempt {attempt}/{self.max_retries} to improve resume score.")
            prompt = prompt_template.format(
                raw_job_description=job,
                extracted_job_keywords=extracted_job_keywords,
                raw_resume=best_resume,
                extracted_resume_keywords=extracted_resume_keywords,
                current_cosine_similarity=best_score,
            )
            improved = await self.md_agent_manager.run(prompt=prompt, model=model)

            if improved.strip() == best_resume.strip():
                logger.info(f"Attempt {attempt} did not produce a new resume. Stopping.")
                break

            emb = await self.embedding_manager.embed(text=improved)
            score = self.calculate_cosine_similarity(emb, extracted_job_keywords_embedding)

            if score > best_score:
                best_resume, best_score = improved, score
                logger.info(f"Attempt {attempt} found improved score: {score}")
                return best_resume, best_score

            logger.info(f"Attempt {attempt} resulted in score: {score}, best score so far: {best_score}")

        return best_resume, best_score

    async def get_resume_for_previewer(self, updated_resume: str, model: str) -> Optional[Dict]:
        prompt_template = prompt_factory.get("structured_resume")
        prompt = prompt_template.format(
            json.dumps(json_schema_factory.get("resume_preview"), indent=2),
            updated_resume,
        )
        raw_output = await self.json_agent_manager.run(prompt=prompt, model=model)

        try:
            resume_preview: ResumePreviewerModel = ResumePreviewerModel.model_validate(raw_output)
            return resume_preview.model_dump()
        except ValidationError as e:
            logger.error(f"Validation error for resume preview: {e}")
            return None

    async def get_analysis_details(self, original_resume: str, improved_resume: str, job_description: str, original_score: float, new_score: float, model: str) -> Dict:
        """Generates details, commentary, and improvements for the resume analysis."""
        analysis_prompt = f"""
        你是一名资深的职业规划顾问。请根据提供的职位描述，分析原始简历与 AI 改进版简历之间的差异。原始匹配分数为 {original_score:.2f} 改进后的分数为 {new_score:.2f}.

        请用**简体中文**输出，并且必须返回一个 JSON 对象，包含以下三个键: "details", "commentary", and "improvements".
        - "details": 一句话简要概述对简历所做的主要改动.
        - "commentary": 一段话说明这些改动为什么能提升简历与目标职位的匹配度.
        - "improvements": 一个数组，每个元素是一个 JSON 对象，包含一个 "suggestion" 键，其值为针对简历的具体改进建议（用简体中文）.

        这里是原始简历:
        ---
        {original_resume}
        ---

        这里是改进后的简历:
        ---
        {improved_resume}
        ---

        这里是职位描述:
        ---
        {job_description}
        ---

        Respond ONLY with the JSON object.
        """

        try:
            analysis_output = await self.json_agent_manager.run(prompt=analysis_prompt, model=model)
            return {
                "details": analysis_output.get("details", ""),
                "commentary": analysis_output.get("commentary", ""),
                "improvements": analysis_output.get("improvements", [])
            }
        except Exception as e:
            logger.error(f"Failed to generate analysis details: {e}")
            return {
                "details": "Analysis could not be generated.",
                "commentary": "",
                "improvements": []
            }

    async def run(self, resume_id: str, job_id: str, model: str = "gpt-3.5-turbo", token: Optional[str] = None) -> Dict:
        resume, processed_resume = await self._get_resume(resume_id)
        job, processed_job = await self._get_job(job_id)

        extracted_job_keywords = ", ".join(json.loads(processed_job.extracted_keywords).get("extracted_keywords", []))
        extracted_resume_keywords = ", ".join(json.loads(processed_resume.extracted_keywords).get("extracted_keywords", []))

        resume_embedding, job_kw_embedding = await asyncio.gather(
            self.embedding_manager.embed(resume.content),
            self.embedding_manager.embed(extracted_job_keywords)
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
                model=model
            )
        )

        logger.info(f"Resume Preview generated: {'Yes' if resume_preview else 'No'}")
        logger.info(f"Analysis Details generated: {analysis_details}")

        execution = {
            "resume_id": resume_id,
            "job_id": job_id,
            "original_score": cosine_similarity_score,
            "new_score": updated_score,
            "resume_preview": resume_preview,
            **analysis_details
        }

        gc.collect()
        return execution

    async def run_and_stream(self, resume_id: str, job_id: str, model: str, token: Optional[str]) -> AsyncGenerator:
        # --- 关键修改：让 stream 方法也能接收 model 和 token ---
        yield f"data: {json.dumps({'status': 'starting', 'message': 'Analyzing resume and job description...'})}\n\n"
        result = await self.run(resume_id, job_id, model, token)
        yield f"data: {json.dumps({'status': 'completed', 'result': result})}\n\n"
