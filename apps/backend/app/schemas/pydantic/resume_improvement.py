from uuid import UUID
from typing import Optional
from pydantic import BaseModel, Field


class ResumeImprovementRequest(BaseModel):
    job_id: UUID = Field(..., description="DB UUID reference to the job")
    resume_id: UUID = Field(..., description="DB UUID reference to the resume")
    model: Optional[str] = Field("gpt-4.1-mini", description="The model to use for the improvement")
    token: Optional[str] = Field(None, description="Token for premium models")