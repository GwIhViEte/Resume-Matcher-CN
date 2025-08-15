from uuid import UUID
from typing import List, Optional
from pydantic import BaseModel, Field


class JobUploadRequest(BaseModel):
    job_descriptions: List[str] = Field(
        ..., description="List of job descriptions in markdown format"
    )
    resume_id: UUID = Field(..., description="UUID reference to the resume")
    model: Optional[str] = Field("gpt-4.1-mini", description="The model to use for processing")
    token: Optional[str] = Field(None, description="Token for premium models")