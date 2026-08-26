import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const state = vi.hoisted(() => ({ authenticated: true, result: "ok" as "ok" | "stale" | "invalid" }));
const mutate = vi.hoisted(() => vi.fn());
vi.mock("@/lib/supabase/route-handler", () => ({ createRouteHandlerClient: () => ({
  applyAuthState: (response: Response) => response,
  supabase: {},
}) }));
vi.mock("@/lib/auth/verified-user", () => ({
  getVerifiedUserId: async () => (state.authenticated ? "a1000000-0000-4000-8000-000000000001" : null),
}));
vi.mock("@/lib/auth/team-context", () => ({ loadTeamContext: async () => ({ teamId: "a2000000-0000-4000-8000-000000000001", seasonId: "a3000000-0000-4000-8000-000000000001", seasonName: "Säsong" }) }));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient: () => ({ kind: "admin" }) }));
vi.mock("@/features/selections/manual-adjustment", () => ({ mutateManualAdjustment: mutate }));

import { POST } from "./route";

const matchId = "a5000000-0000-4000-8000-000000000001";
const outgoing = "a4000000-0000-4000-8000-000000000001";
const incoming = "a4000000-0000-4000-8000-000000000002";
function request(values: Record<string, string>) {
  return new NextRequest(`https://app.example/matches/${matchId}/adjust/save`, { method: "POST", body: new URLSearchParams(values) });
}

describe("manual adjustment save route", () => {
  beforeEach(() => { state.authenticated = true; state.result = "ok"; mutate.mockReset().mockImplementation(async () => state.result); });

  it("uses the server-only mutation and redirects after a valid adjustment", async () => {
    const response = await POST(request({ outgoingPlayerId: outgoing, incomingPlayerId: incoming, fingerprint: "a".repeat(32) }), { params: Promise.resolve({ id: matchId }) });
    expect(mutate).toHaveBeenCalledWith({ kind: "admin" }, "create_manual_regular_adjustment", expect.objectContaining({ matchId, outgoingPlayerId: outgoing, incomingPlayerId: incoming }));
    expect(response.status).toBe(303);
    expect(response.headers.get("location")).toBe(`https://app.example/matches/${matchId}?adjustment=saved`);
  });

  it("rejects malformed and stale submissions without leaking database details", async () => {
    const malformed = await POST(request({ outgoingPlayerId: "bad", incomingPlayerId: incoming, fingerprint: "no" }), { params: Promise.resolve({ id: matchId }) });
    expect(malformed.headers.get("location")).toContain("error=invalid");
    expect(mutate).not.toHaveBeenCalled();
    state.result = "stale";
    const stale = await POST(request({ outgoingPlayerId: outgoing, incomingPlayerId: incoming, fingerprint: "b".repeat(32) }), { params: Promise.resolve({ id: matchId }) });
    expect(stale.headers.get("location")).toContain("error=stale");
  });

  it("redirects an unauthenticated request before mutation", async () => {
    state.authenticated = false;
    const response = await POST(request({ outgoingPlayerId: outgoing, incomingPlayerId: incoming, fingerprint: "a".repeat(32) }), { params: Promise.resolve({ id: matchId }) });
    expect(response.headers.get("location")).toContain("/login?next=");
    expect(mutate).not.toHaveBeenCalled();
  });
});
