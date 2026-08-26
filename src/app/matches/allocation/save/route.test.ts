import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const state = vi.hoisted(() => ({ authenticated: true }));
const saveAllocationMock = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/route-handler", () => ({
  createRouteHandlerClient: () => ({
    applyAuthState: (response: Response) => response,
    supabase: {},
  }),
}));
vi.mock("@/lib/auth/verified-user", () => ({
  getVerifiedUserId: async () => (state.authenticated ? "coach-1" : null),
}));
vi.mock("@/lib/auth/team-context", () => ({
  loadTeamContext: async () => ({ teamId: "team-1", seasonId: "season-1", seasonName: "Säsong" }),
}));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient: () => ({ kind: "admin" }) }));
vi.mock("@/features/selections/save-allocation", () => ({ saveAllocation: saveAllocationMock }));

import { POST } from "./route";

function request(values: Record<string, string>) {
  return new NextRequest("https://app.example/matches/allocation/save", {
    method: "POST", body: new URLSearchParams(values),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
  });
}

describe("allocation save route", () => {
  beforeEach(() => {
    state.authenticated = true;
    saveAllocationMock.mockReset().mockResolvedValue({ ok: true, savedCount: 2 });
  });

  it("saves a valid current preview and redirects with 303", async () => {
    const response = await POST(request({ fingerprint: "a".repeat(32) }));
    expect(saveAllocationMock).toHaveBeenCalledWith(
      expect.anything(), { kind: "admin" }, "coach-1", "team-1", "season-1", expect.any(String), "a".repeat(32),
    );
    expect(response.status).toBe(303);
    expect(response.headers.get("location")).toBe("https://app.example/matches?allocation=saved");
  });

  it("rejects malformed or stale preview state without saving", async () => {
    const malformed = await POST(request({ fingerprint: "no" }));
    expect(malformed.headers.get("location")).toBe("https://app.example/matches/allocation/preview?error=stale");
    expect(saveAllocationMock).not.toHaveBeenCalled();

    saveAllocationMock.mockResolvedValueOnce({ ok: false, error: "STALE_PREVIEW" });
    const stale = await POST(request({ fingerprint: "b".repeat(32) }));
    expect(stale.headers.get("location")).toContain("error=stale");
  });

  it("redirects unauthenticated requests to login", async () => {
    state.authenticated = false;
    const response = await POST(request({ fingerprint: "a".repeat(32) }));
    expect(response.status).toBe(303);
    expect(response.headers.get("location")).toBe("https://app.example/login?next=/matches");
    expect(saveAllocationMock).not.toHaveBeenCalled();
  });
});
