import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  agentRules: false,
  images: {
    remotePatterns: [{protocol: "https", hostname: "innebandy.se", pathname: "/media/**"}],
    minimumCacheTTL: 31536000,
  },
};

export default nextConfig;
