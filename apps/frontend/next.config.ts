import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
    async rewrites() {
    // This rewrite is only for local development
    if (process.env.NODE_ENV === 'development') {
        return [
        {
            source: '/api_be/:path*',
            destination: 'http://localhost:8000/:path*',
        },
        ];
    }
    return [];
  },
};

export default nextConfig;
