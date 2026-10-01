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
vi.mock("@/lib/auth/team-context", () => ({ loadTeamContext: async () => ({ teamId: "a2000000-0000-4000-8000-000000000001", seasonId: "a3000000-0000-4000-8000-000000000001", seasonName: "Säsong", role: "coach" }) }));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient: () => ({ kind: "admin" }) }));
vi.mock("@/features/selections/manual-adjustment", async () => ({ mutateManualAdjustments: mutate, parseAdjustmentPairs: (await vi.importActual<typeof import("@/features/selections/manual-adjustment")>("@/features/selections/manual-adjustment")).parseAdjustmentPairs }));

import { POST } from "./route";

const matchId = "a5000000-0000-4000-8000-000000000001";
const outgoing = "a4000000-0000-4000-8000-000000000001";
const incoming = "a4000000-0000-4000-8000-000000000002";
function request(values: Record<string, string | string[]>) {
  return new NextRequest(`https://app.example/matches/${matchId}/adjust/save`, { method: "POST", body: new URLSearchParams(Object.entries(values).flatMap(([key, value]) => Array.isArray(value) ? value.map((item) => [key, item]) : [[key, value]])) });
}

describe("manual adjustment save route", () => {
  beforeEach(() => { state.authenticated = true; state.result = "ok"; mutate.mockReset().mockImplementation(async () => state.result); });

  it("uses the server-only mutation and redirects after a valid adjustment", async () => {
    const response = await POST(request({ outgoingPlayerId: outgoing, [`incoming:${outgoing}`]: incoming, fingerprint: "a".repeat(32) }), { params: Promise.resolve({ id: matchId }) });
    expect(mutate).toHaveBeenCalledWith({ kind: "admin" }, expect.objectContaining({ matchId, pairs: [{ outgoingPlayerId: outgoing, incomingPlayerId: incoming }] }));
    expect(response.status).toBe(303);
    expect(response.headers.get("location")).toBe(`https://app.example/matches/${matchId}?adjustment=saved`);
  });

  it("sends several pairs in one atomic call and rejects overlapping ids", async () => {
    const outgoing2 = "a4000000-0000-4000-8000-000000000003";
    const incoming2 = "a4000000-0000-4000-8000-000000000004";
    const response = await POST(request({ outgoingPlayerId: [outgoing, outgoing2], [`incoming:${outgoing}`]: incoming, [`incoming:${outgoing2}`]: incoming2, fingerprint: "a".repeat(32) }), { params: Promise.resolve({ id: matchId }) });
    expect(mutate).toHaveBeenCalledTimes(1);
    expect(mutate).toHaveBeenCalledWith({ kind: "admin" }, expect.objectContaining({ pairs: [{ outgoingPlayerId: outgoing, incomingPlayerId: incoming }, { outgoingPlayerId: outgoing2, incomingPlayerId: incoming2 }] }));
    expect(response.headers.get("location")).toContain("adjustment=saved");
    mutate.mockClear();
    const overlap = await POST(request({ outgoingPlayerId: [outgoing, outgoing2], [`incoming:${outgoing}`]: incoming, [`incoming:${outgoing2}`]: incoming, fingerprint: "a".repeat(32) }), { params: Promise.resolve({ id: matchId }) });
    expect(overlap.headers.get("location")).toContain("error=invalid");
    expect(mutate).not.toHaveBeenCalled();
  });

  it("rejects malformed and stale submissions without leaking database details", async () => {
    const malformed = await POST(request({ outgoingPlayerId: "bad", "incoming:bad": incoming, fingerprint: "no" }), { params: Promise.resolve({ id: matchId }) });
    expect(malformed.headers.get("location")).toContain("error=invalid");
    expect(mutate).not.toHaveBeenCalled();
    state.result = "stale";
    const stale = await POST(request({ outgoingPlayerId: outgoing, [`incoming:${outgoing}`]: incoming, fingerprint: "b".repeat(32) }), { params: Promise.resolve({ id: matchId }) });
    expect(stale.headers.get("location")).toContain("error=stale");
  });

  it("redirects an unauthenticated request before mutation", async () => {
    state.authenticated = false;
    const response = await POST(request({ outgoingPlayerId: outgoing, [`incoming:${outgoing}`]: incoming, fingerprint: "a".repeat(32) }), { params: Promise.resolve({ id: matchId }) });
    expect(response.headers.get("location")).toContain("/login?next=");
    expect(mutate).not.toHaveBeenCalled();
  });
});
