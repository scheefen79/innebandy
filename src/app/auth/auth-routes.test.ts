import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const routeAuthState = vi.hoisted(() => ({ loginFails: false, signedOut: false }));

vi.mock("@supabase/ssr", () => ({
  createServerClient: (
    _url: string,
    _key: string,
    options: {
      cookies: {
        setAll: (
          cookies: Array<{
            name: string;
            options: { maxAge?: number; path: string };
            value: string;
          }>,
          headers: Record<string, string>,
        ) => void;
      };
    },
  ) => ({
    auth: {
      async signInWithPassword() {
        if (routeAuthState.loginFails) {
          return { error: new Error("User not found") };
        }

        options.cookies.setAll(
          [{ name: "sb-session", options: { path: "/" }, value: "signed-in" }],
          {},
        );
        return { error: null };
      },
      async signOut() {
        routeAuthState.signedOut = true;
        options.cookies.setAll(
          [
            {
              name: "sb-session",
              options: { maxAge: 0, path: "/" },
              value: "",
            },
          ],
          {},
        );
        return { error: null };
      },
    },
  }),
}));

import { POST as login } from "./login/route";
import { POST as logout } from "./logout/route";

const expectedCacheControl =
  "private, no-cache, no-store, must-revalidate, max-age=0";

function createLoginRequest(values: Record<string, string>) {
  return new NextRequest("https://app.example/auth/login", {
    body: new URLSearchParams(values),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    method: "POST",
  });
}

function expectPrivateAuthResponse(response: Response) {
  expect(response.headers.get("cache-control")).toBe(expectedCacheControl);
  expect(response.headers.get("expires")).toBe("0");
  expect(response.headers.get("pragma")).toBe("no-cache");
}

describe("auth route handlers", () => {
  beforeEach(() => {
    routeAuthState.loginFails = false;
    routeAuthState.signedOut = false;
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "publishable-test-key";
  });

  it("returns a private 303 with the session cookie after successful login", async () => {
    const response = await login(
      createLoginRequest({
        email: "COACH@example.test ",
        next: "/?filter=active",
        password: "valid-password",
      }),
    );

    expect(response.status).toBe(303);
    expect(response.headers.get("location")).toBe(
      "https://app.example/?filter=active",
    );
    expect(response.cookies.get("sb-session")?.value).toBe("signed-in");
    expectPrivateAuthResponse(response);
  });

  it("returns only a generic error code after failed login", async () => {
    routeAuthState.loginFails = true;

    const response = await login(
      createLoginRequest({
        email: "missing@example.test",
        next: "/spelare",
        password: "wrong-password",
      }),
    );
    const location = response.headers.get("location");

    expect(response.status).toBe(303);
    expect(location).toBe(
      "https://app.example/login?error=invalid&next=%2Fspelare",
    );
    expect(location).not.toContain("missing@example.test");
    expect(location).not.toContain("User+not+found");
    expectPrivateAuthResponse(response);
  });

  it("returns a private 303 and expires the session cookie on logout", async () => {
    const response = await logout(
      new NextRequest("https://app.example/auth/logout", { method: "POST" }),
    );

    expect(routeAuthState.signedOut).toBe(true);
    expect(response.status).toBe(303);
    expect(response.headers.get("location")).toBe("https://app.example/login");
    expect(response.cookies.get("sb-session")?.value).toBe("");
    expect(response.headers.get("set-cookie")).toContain("Max-Age=0");
    expectPrivateAuthResponse(response);
  });
});
