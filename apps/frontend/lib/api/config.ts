const EXPLICIT_API_URL = process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, '')
const FALLBACK_API_PORT = process.env.NEXT_PUBLIC_API_PORT ?? '8000'

export function getApiBaseUrl(): string {
  if (EXPLICIT_API_URL && EXPLICIT_API_URL.length > 0) {
    return EXPLICIT_API_URL
  }

  if (typeof window !== 'undefined') {
    const { protocol, hostname } = window.location
    const portSegment = FALLBACK_API_PORT ? `:${FALLBACK_API_PORT}` : ''
    return `${protocol}//${hostname}${portSegment}`
  }

  return `http://localhost:${FALLBACK_API_PORT}`
}

