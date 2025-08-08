import enum
from typing import Optional, List
from pydantic import BaseModel, Field

class EmploymentTypeEnum(str, enum.Enum):
    FULL_TIME = "Full-time"
    PART_TIME = "Part-time"
    CONTRACT = "Contract"
    INTERNSHIP = "Internship"
    TEMPORARY = "Temporary"
    NOT_SPECIFIED = "Not Specified"

    @classmethod
    def _missing_(cls, value: object):
        if isinstance(value, str):
            value_lower = value.lower()
            for member in cls:
                if member.value.lower() == value_lower:
                    return member
        return cls.NOT_SPECIFIED

class RemoteStatusEnum(str, enum.Enum):
    FULLY_REMOTE = "Fully Remote"
    HYBRID = "Hybrid"
    ON_SITE = "On-site"
    REMOTE = "Remote"
    NOT_SPECIFIED = "Not Specified"
    MULTIPLE_LOCATIONS = "Multiple Locations"

    @classmethod
    def _missing_(cls, value: object):
        if isinstance(value, str):
            value_lower = value.lower()
            for member in cls:
                if member.value.lower() == value_lower:
                    return member
        return cls.NOT_SPECIFIED

class CompanyProfile(BaseModel):
    company_name: Optional[str] = Field(None, alias="companyName")
    industry: Optional[str] = None
    website: Optional[str] = None
    description: Optional[str] = None

class Location(BaseModel):
    city: Optional[str] = None
    state: Optional[str] = None
    country: Optional[str] = None
    remote_status: Optional[RemoteStatusEnum] = Field(None, alias="remoteStatus")

class Qualifications(BaseModel):
    required: Optional[List[str]] = None
    preferred: Optional[List[str]] = None

class CompensationAndBenefits(BaseModel):
    salary_range: Optional[str] = Field(None, alias="salaryRange")
    benefits: Optional[List[str]] = None

class ApplicationInfo(BaseModel):
    how_to_apply: Optional[str] = Field(None, alias="howToApply")
    apply_link: Optional[str] = Field(None, alias="applyLink")
    contact_email: Optional[str] = Field(None, alias="contactEmail")

class StructuredJobModel(BaseModel):
    job_title: Optional[str] = Field(None, alias="jobTitle")
    company_profile: Optional[CompanyProfile] = Field(None, alias="companyProfile")
    location: Optional[Location] = None
    date_posted: Optional[str] = Field(None, alias="datePosted")
    employment_type: Optional[EmploymentTypeEnum] = Field(None, alias="employmentType")
    job_summary: Optional[str] = Field(None, alias="jobSummary")
    key_responsibilities: Optional[List[str]] = Field(None, alias="keyResponsibilities")
    qualifications: Optional[Qualifications] = None
    compensation_and_benefits: Optional[CompensationAndBenefits] = Field(None, alias="compensationAndBenefits")
    application_info: Optional[ApplicationInfo] = Field(None, alias="applicationInfo")
    extracted_keywords: Optional[List[str]] = Field(None, alias="extractedKeywords")

    class ConfigDict:
        validate_by_name = True
        str_strip_whitespace = True