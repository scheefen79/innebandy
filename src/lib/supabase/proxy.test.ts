import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const authState = vi.hoisted(() => ({ authenticated: false, refreshCookies: true }));

vi.mock("@supabase/ssr", () => ({
  createServerClient: (
    _url: string,
    _key: string,
    options: {
      cookies: {
        setAll: (
          cookies: Array<{ name: string; options: { path: string }; value: string }>,
          headers: Record<string, string>,
        ) => void;
      };
    },
  ) => ({
    auth: {
      async getClaims() {
        if (authState.refreshCookies) {
          options.cookies.setAll(
            [{ name: "sb-session", options: { path: "/" }, value: "refreshed" }],
            {
              "Cache-Control": "private, no-store",
              Expires: "0",
              Pragma: "no-cache",
            },
          );
        }
        return authState.authenticated
          ? { data: { claims: { sub: "coach-id" } } }
          : { data: null };
      },
    },
  }),
}));

import { updateSession } from "./proxy";

describe("updateSession", () => {
  beforeEach(() => {
    authState.authenticated = false;
    authState.refreshCookies = true;
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "publishable-test-key";
  });

  it("redirects an unauthenticated request and preserves refreshed auth state", async () => {
    const response = await updateSession(
      new NextRequest("https://app.example/spelare?filter=active"),
    );

    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toBe(
      "https://app.example/login?next=%2Fspelare%3Ffilter%3Dactive",
    );
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(response.cookies.get("sb-session")?.value).toBe("refreshed");
  });

  it("redirects an authenticated user away from login to a safe next path", async () => {
    authState.authenticated = true;

    const response = await updateSession(
      new NextRequest("https://app.example/login?next=/?filter=active"),
    );

    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toBe(
      "https://app.example/?filter=active",
    );
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(response.cookies.get("sb-session")?.value).toBe("refreshed");
  });

  it("allows an authenticated protected request with private cache headers", async () => {
    authState.authenticated = true;

    const response = await updateSession(new NextRequest("https://app.example/"));

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(response.cookies.get("sb-session")?.value).toBe("refreshed");
  });

  it("keeps protected responses private even when no cookie refresh occurs", async () => {
    authState.authenticated = true;
    authState.refreshCookies = false;

    const response = await updateSession(new NextRequest("https://app.example/"));

    expect(response.headers.get("cache-control")).toContain("private");
    expect(response.headers.get("cache-control")).toContain("no-store");
  });

  it("forwards the verified user id to the request so pages skip a second claims check", async () => {
    authState.authenticated = true;

    const response = await updateSession(new NextRequest("https://app.example/"));

    expect(response.headers.get("x-middleware-override-headers")).toContain(
      "x-innebandy-verified-user-id",
    );
    expect(response.headers.get("x-middleware-request-x-innebandy-verified-user-id")).toBe(
      "coach-id",
    );
  });
});
