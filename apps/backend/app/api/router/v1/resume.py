import logging
import traceback
import uuid as uuid_pkg
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi import (
	APIRouter,
	Depends,
	File,
	HTTPException,
	Query,
	Request,
	UploadFile,
	status,
)
from fastapi.responses import JSONResponse, StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import get_db_session
from app.dependencies.locale import get_request_locale
from app.i18n import translate
from app.models import Token
from app.schemas.pydantic import ResumeImprovementRequest
from app.services import (
	JobKeywordExtractionError,
	JobNotFoundError,
	JobParsingError,
	ResumeKeywordExtractionError,
	ResumeNotFoundError,
	ResumeParsingError,
	ResumeService,
	ResumeValidationError,
	ScoreImprovementService,
)

resume_router = APIRouter()
logger = logging.getLogger(__name__)


@resume_router.post(
	"/admin/generate-token",
	summary="Generate a new token for premium features",
	tags=["Admin"],
)
async def generate_token(
	days: int = Query(30, description="Number of days the token will be valid for"),
	db: AsyncSession = Depends(get_db_session),
	locale: str = Depends(get_request_locale),
):
	"""
	Generates a new unique token and stores it in the database.
	"""
	new_token_str = str(uuid_pkg.uuid4())
	now = datetime.now(timezone.utc)
	expires_at = now + timedelta(days=days)

	new_token = Token(
		token=new_token_str,
		is_valid=True,
		created_at=now,
		expires_at=expires_at,
	)
	db.add(new_token)
	await db.commit()

	return {
		"token": new_token_str,
		"message": translate('responses.token_generated', locale),
		"valid_for_days": days,
		"expires_at": expires_at.isoformat(),
	}


@resume_router.post(
	"/upload",
	summary="Upload a resume in PDF or DOCX format and store it into DB in HTML/Markdown format",
)
async def upload_resume(
	request: Request,
	file: UploadFile = File(...),
	model: str = Query("gpt-3.5-turbo"),
	token: str | None = Query(None),
	db: AsyncSession = Depends(get_db_session),
	locale: str = Depends(get_request_locale),
):
	"""
	Accepts a PDF or DOCX file, converts it to HTML/Markdown, and stores it in the database.
	"""
	request_id = getattr(request.state, "request_id", str(uuid4()))

	allowed_content_types = {
		"application/pdf",
		"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
	}

	if file.content_type not in allowed_content_types:
		raise HTTPException(
			status_code=status.HTTP_400_BAD_REQUEST,
			detail=translate('errors.file.invalid_type', locale),
		)

	file_bytes = await file.read()
	if not file_bytes:
		raise HTTPException(
			status_code=status.HTTP_400_BAD_REQUEST,
			detail=translate('errors.file.empty', locale),
		)

	try:
		resume_service = ResumeService(db, locale)
		resume_id = await resume_service.convert_and_store_resume(
			file_bytes=file_bytes,
			file_type=file.content_type,
			filename=file.filename,
			content_type="md",
			model=model,
			token=token,
		)
	except ResumeValidationError as exc:
		logger.warning("Resume validation failed: %s", exc)
		raise HTTPException(
			status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
			detail=str(exc),
		)
	except HTTPException:
		raise
	except Exception as exc:  # noqa: BLE001
		logger.error("Error processing file: %s - traceback: %s", exc, traceback.format_exc())
		raise HTTPException(
			status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
			detail=translate('errors.generic', locale),
		)

	return {
		"message": translate('responses.resume_uploaded', locale),
		"request_id": request_id,
		"resume_id": resume_id,
	}


@resume_router.post(
	"/improve",
	summary="Score and improve a resume against a job description",
)
async def score_and_improve(
	request: Request,
	payload: ResumeImprovementRequest,
	db: AsyncSession = Depends(get_db_session),
	stream: bool = Query(False, description="Enable streaming response using Server-Sent Events"),
	locale: str = Depends(get_request_locale),
):
	"""
	Scores and improves a resume against a job description.
	"""
	request_id = getattr(request.state, "request_id", str(uuid4()))
	headers = {"X-Request-ID": request_id}

	try:
		score_improvement_service = ScoreImprovementService(db=db, locale=locale)

		if stream:
			raise HTTPException(status_code=501, detail="Streaming not fully implemented with new params yet.")
		else:
			improvements = await score_improvement_service.run(
				resume_id=str(payload.resume_id),
				job_id=str(payload.job_id),
				model=payload.model,
				token=payload.token,
			)
			return JSONResponse(
				content={"request_id": request_id, "data": improvements},
				headers=headers,
			)
	except (ResumeNotFoundError, JobNotFoundError, ResumeParsingError, JobParsingError) as exc:
		logger.error("%s", exc)
		raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc))
	except (ResumeKeywordExtractionError, JobKeywordExtractionError) as exc:
		logger.warning("%s", exc)
		raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))
	except HTTPException:
		raise
	except Exception as exc:  # noqa: BLE001
		logger.error("Error: %s - traceback: %s", exc, traceback.format_exc())
		raise HTTPException(
			status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
			detail=translate('errors.generic', locale),
		)


@resume_router.get(
	"",
	summary="Get resume data from both resume and processed_resume models",
)
async def get_resume(
	request: Request,
	resume_id: str = Query(..., description="Resume ID to fetch data for"),
	db: AsyncSession = Depends(get_db_session),
	locale: str = Depends(get_request_locale),
):
	"""
	Retrieves resume data from both resume_model and processed_resume model by resume_id.
	"""
	request_id = getattr(request.state, "request_id", str(uuid4()))
	headers = {"X-Request-ID": request_id}

	try:
		if not resume_id:
			raise HTTPException(
				status_code=status.HTTP_400_BAD_REQUEST,
				detail=translate('errors.resume.id_required', locale),
			)

		resume_service = ResumeService(db, locale)
		resume_data = await resume_service.get_resume_with_processed_data(resume_id=resume_id)

		if not resume_data:
			raise ResumeNotFoundError(message=translate('errors.resume.not_found', locale, resume_id=resume_id))

		return JSONResponse(content={"request_id": request_id, "data": resume_data}, headers=headers)

	except ResumeNotFoundError as exc:
		logger.error("%s", exc)
		raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))
	except Exception as exc:  # noqa: BLE001
		logger.error("Error fetching resume: %s - traceback: %s", exc, traceback.format_exc())
		raise HTTPException(
			status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
			detail=translate('errors.resume.fetch_failed', locale),
		)
