import os
import uuid
import json
import tempfile
import logging
import pdfplumber
import docx
from typing import Dict, Optional
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import ValidationError

from app.models import Resume, ProcessedResume, Token
from app.agent import AgentManager
from app.prompt import prompt_factory
from app.schemas.json import json_schema_factory
from app.schemas.pydantic import StructuredResumeModel
from .exceptions import ResumeNotFoundError, ResumeValidationError

logger = logging.getLogger(__name__)


class ResumeService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.json_agent_manager = AgentManager()

    def _extract_text_from_pdf(self, file_path: str) -> str:
        """Extracts text from a PDF file."""
        try:
            with pdfplumber.open(file_path) as pdf:
                text_parts = []
                for page in pdf.pages:
                    text = page.extract_text()
                    if text:
                        text_parts.append(text)
                return "\n".join(text_parts)
        except Exception as e:
            logger.error(f"PDF extraction failed: {str(e)}")
            raise ResumeValidationError(message=f"PDF文件解析失败: {str(e)}")

    def _extract_text_from_docx(self, file_path: str) -> str:
        """Extracts text from a DOCX file."""
        try:
            doc = docx.Document(file_path)
            return "\n".join(para.text for para in doc.paragraphs if para.text.strip())
        except Exception as e:
            logger.error(f"DOCX extraction failed: {str(e)}")
            raise ResumeValidationError(message=f"Word文档解析失败: {str(e)}")
    
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

    async def convert_and_store_resume(
        self, file_bytes: bytes, file_type: str, filename: str, content_type: str = "md", model: str = "gpt-3.5-turbo", token: Optional[str] = None
    ):
        """
        Converts resume file (PDF/DOCX) to text and stores it in the database.
        """
        if model in ["gpt-4o"]:
            # --- 关键修改：调用只验证的函数 ---
            is_valid_token = await self._validate_token(token)
            if not is_valid_token:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="高级模型的Token无效、过期或丢失。",
                )

        file_extension = self._get_file_extension(file_type)
        
        with tempfile.NamedTemporaryFile(delete=False, suffix=file_extension) as temp_file:
            temp_file.write(file_bytes)
            temp_path = temp_file.name

        try:
            if file_extension == ".pdf":
                text_content = self._extract_text_from_pdf(temp_path)
            elif file_extension == ".docx":
                text_content = self._extract_text_from_docx(temp_path)
            else:
                raise ValueError(f"不支持的文件类型: {file_type}")

            if not text_content or not text_content.strip():
                raise ResumeValidationError(
                    message="无法从文档中提取文本。请确保文件包含文本内容而非图片。"
                )

            try:
                resume_id = await self._store_resume_in_db(text_content, content_type)
                await self._extract_and_store_structured_resume(
                    resume_id=resume_id, resume_text=text_content, model=model
                )
                await self.db.commit()
                return resume_id
            except Exception as e:
                await self.db.rollback()
                raise
                
        finally:
            if os.path.exists(temp_path):
                try:
                    os.remove(temp_path)
                except Exception as e:
                    logger.warning(f"Failed to remove temp file: {str(e)}")

    def _get_file_extension(self, file_type: str) -> str:
        mime_to_ext = {
            "application/pdf": ".pdf",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document": ".docx"
        }
        return mime_to_ext.get(file_type, "")

    async def _store_resume_in_db(self, text_content: str, content_type: str) -> str:
        resume_id = str(uuid.uuid4())
        resume = Resume(
            resume_id=resume_id, 
            content=text_content, 
            content_type=content_type
        )
        self.db.add(resume)
        await self.db.flush()
        return resume_id

    async def _extract_and_store_structured_resume(
        self, resume_id: str, resume_text: str, model: str
    ) -> None:
        try:
            structured_resume = await self._extract_structured_json(resume_text, model=model)
            if not structured_resume:
                logger.error("Structured resume extraction returned None.")
                raise ResumeValidationError(
                    resume_id=resume_id,
                    message="无法从简历中提取结构化数据。请确保简历包含必要的信息。",
                )

            def safe_json_dumps(data: any, key: str = None) -> Optional[str]:
                if data is None:
                    return None
                if key:
                    return json.dumps({key: data})
                return json.dumps(data)

            processed_resume = ProcessedResume(
                resume_id=resume_id,
                personal_data=safe_json_dumps(structured_resume.get("personal_data")),
                experiences=safe_json_dumps(
                    structured_resume.get("experiences", []), "experiences"
                ),
                projects=safe_json_dumps(
                    structured_resume.get("projects", []), "projects"
                ),
                skills=safe_json_dumps(
                    structured_resume.get("skills", []), "skills"
                ),
                research_work=safe_json_dumps(
                    structured_resume.get("research_work", []), "research_work"
                ),
                achievements=safe_json_dumps(
                    structured_resume.get("achievements", []), "achievements"
                ),
                education=safe_json_dumps(
                    structured_resume.get("education", []), "education"
                ),
                extracted_keywords=safe_json_dumps(
                    structured_resume.get("extracted_keywords", []), "extracted_keywords"
                ),
            )

            self.db.add(processed_resume)
            await self.db.flush()
            
        except ResumeValidationError:
            raise
        except Exception as e:
            logger.error(f"Error storing structured resume: {str(e)}")
            raise ResumeValidationError(
                resume_id=resume_id,
                message=f"存储结构化简历数据失败: {str(e)}",
            )

    async def _extract_structured_json(self, resume_text: str, model: str) -> Optional[Dict]:
        prompt_template = prompt_factory.get("structured_resume")
        prompt = prompt_template.format(
            json.dumps(json_schema_factory.get("structured_resume"), indent=2),
            resume_text,
        )
        logger.debug(f"Structured Resume Prompt: {prompt[:500]}...")
        
        raw_output = await self.json_agent_manager.run(prompt=prompt, model=model)

        try:
            structured_resume = StructuredResumeModel.model_validate(raw_output)
            return structured_resume.model_dump()
        except ValidationError as e:
            logger.error(f"Validation error: {e}")
            error_details = []
            for error in e.errors():
                field = " -> ".join(str(loc) for loc in error["loc"])
                error_details.append(f"{field}: {error['msg']}")

            user_friendly_message = "简历验证失败: " + "; ".join(error_details)
            raise ResumeValidationError(
                validation_error=user_friendly_message,
                message=user_friendly_message,
            )

    async def get_resume_with_processed_data(self, resume_id: str) -> Optional[Dict]:
        resume_query = select(Resume).where(Resume.resume_id == resume_id)
        resume_result = await self.db.execute(resume_query)
        resume = resume_result.scalars().first()

        if not resume:
            raise ResumeNotFoundError(resume_id=resume_id)

        processed_query = select(ProcessedResume).where(
            ProcessedResume.resume_id == resume_id
        )
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
            def safe_json_loads(data: str, key: str = None) -> any:
                if not data:
                    return [] if key else None
                try:
                    parsed = json.loads(data)
                    return parsed.get(key, []) if key else parsed
                except json.JSONDecodeError:
                    logger.error(f"Failed to parse JSON for {key}: {data[:100]}...")
                    return [] if key else None

            combined_data["processed_resume"] = {
                "personal_data": safe_json_loads(processed_resume.personal_data),
                "experiences": safe_json_loads(processed_resume.experiences, "experiences"),
                "projects": safe_json_loads(processed_resume.projects, "projects"),
                "skills": safe_json_loads(processed_resume.skills, "skills"),
                "research_work": safe_json_loads(processed_resume.research_work, "research_work"),
                "achievements": safe_json_loads(processed_resume.achievements, "achievements"),
                "education": safe_json_loads(processed_resume.education, "education"),
                "extracted_keywords": safe_json_loads(
                    processed_resume.extracted_keywords, "extracted_keywords"
                ),
                "processed_at": processed_resume.processed_at.isoformat()
                if processed_resume.processed_at
                else None,
            }

        return combined_data
