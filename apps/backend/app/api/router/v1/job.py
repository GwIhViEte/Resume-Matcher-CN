import logging
import traceback
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import get_db_session
from app.dependencies.locale import get_request_locale
from app.i18n import translate
from app.schemas.pydantic.job import JobUploadRequest
from app.services import JobNotFoundError, JobService

job_router = APIRouter()
logger = logging.getLogger(__name__)


@job_router.post(
	"/upload",
	summary="Store the job posting in the database by parsing it into structured JSON",
)
async def upload_job(
	payload: JobUploadRequest,
	request: Request,
	db: AsyncSession = Depends(get_db_session),
	locale: str = Depends(get_request_locale),
):
	"""
	Accepts a job description as JSON and stores it in the database.
	"""
	request_id = getattr(request.state, "request_id", str(uuid4()))

	allowed_content_types = {"application/json"}
	content_type = request.headers.get("content-type")

	if not content_type:
		raise HTTPException(
			status_code=status.HTTP_400_BAD_REQUEST,
			detail=translate('errors.request.missing_content_type', locale),
		)

	if content_type not in allowed_content_types:
		raise HTTPException(
			status_code=status.HTTP_400_BAD_REQUEST,
			detail=translate(
				'errors.request.invalid_content_type',
				locale,
				allowed=', '.join(sorted(allowed_content_types)),
			),
		)

	try:
		job_service = JobService(db, locale)
		job_ids = await job_service.create_and_store_job(payload.model_dump())
	except AssertionError as exc:
		raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
	except HTTPException:
		raise
	except Exception as exc:  # noqa: BLE001
		logger.error("Error uploading job: %s", exc)
		raise HTTPException(
			status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
			detail=translate('errors.generic', locale),
		)

	return {
		"message": translate('responses.job_uploaded', locale),
		"job_id": job_ids,
		"request": {"request_id": request_id},
	}


@job_router.get(
	"",
	summary="Get job data from both job and processed_job models",
)
async def get_job(
	request: Request,
	job_id: str = Query(..., description="Job ID to fetch data for"),
	db: AsyncSession = Depends(get_db_session),
	locale: str = Depends(get_request_locale),
):
	"""Retrieve job data from both job and processed_job models by job_id."""
	request_id = getattr(request.state, "request_id", str(uuid4()))
	headers = {"X-Request-ID": request_id}

	try:
		if not job_id:
			raise HTTPException(
				status_code=status.HTTP_400_BAD_REQUEST,
				detail=translate('errors.job.id_required', locale),
			)

		job_service = JobService(db, locale)
		job_data = await job_service.get_job_with_processed_data(job_id=job_id)

		if not job_data:
			raise JobNotFoundError(message=translate('errors.job.not_found', locale, job_id=job_id))

		return JSONResponse(content={"request_id": request_id, "data": job_data}, headers=headers)

	except JobNotFoundError as exc:
		logger.error("%s", exc)
		raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))
	except Exception as exc:  # noqa: BLE001
		logger.error("Error fetching job: %s - traceback: %s", exc, traceback.format_exc())
		raise HTTPException(
			status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
			detail=translate('errors.job.fetch_failed', locale),
		)
