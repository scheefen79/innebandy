import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  agentRules: false,
  images: {
    remotePatterns: [{protocol: "https", hostname: "innebandy.se", pathname: "/media/**"}],
  },
};

export default nextConfig;
