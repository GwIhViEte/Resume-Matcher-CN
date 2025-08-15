import { ImprovedResult } from '@/components/common/resume_previewer_context';

const API_URL = process.env.NEXT_PUBLIC_API_URL!;

/** Uploads job descriptions and returns a job_id */
export async function uploadJobDescriptions(
    descriptions: string[],
    resumeId: string,
    model: string,
    token: string | null
): Promise<string> {
    const res = await fetch(`${API_URL}/api/v1/jobs/upload`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        // --- 关键修改：在这里把 model 和 token 也加进去 ---
        body: JSON.stringify({ 
            job_descriptions: descriptions, 
            resume_id: resumeId,
            model: model,
            token: token
        }),
    });
    if (!res.ok) throw new Error(`Upload failed with status ${res.status}`);
    const data = await res.json();
    console.log('Job upload response:', data);
    return data.job_id[0];
}

/** Improves the resume and returns the full preview object */
export async function improveResume(
    resumeId: string,
    jobId: string,
    model: string,
    token: string | null
): Promise<ImprovedResult> {
    let response: Response;
    try {
        response = await fetch(`${API_URL}/api/v1/resumes/improve`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ resume_id: resumeId, job_id: jobId, model, token }),
        });
    } catch (networkError) {
        console.error('Network error during improveResume:', networkError);
        throw networkError;
    }

    const text = await response.text();
    if (!response.ok) {
        console.error('Improve failed response body:', text);
        throw new Error(`Improve failed with status ${response.status}: ${text}`);
    }

    let data: ImprovedResult;
    try {
        data = JSON.parse(text) as ImprovedResult;
    } catch (parseError) {
        console.error('Failed to parse improveResume response:', parseError, 'Raw response:', text);
        throw parseError;
    }

    console.log('Resume improvement response:', data);
    return data;
}