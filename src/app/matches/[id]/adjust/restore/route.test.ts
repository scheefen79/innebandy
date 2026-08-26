import { expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const mutate = vi.hoisted(() => vi.fn().mockResolvedValue("ok"));
vi.mock("@/lib/supabase/route-handler", () => ({ createRouteHandlerClient: () => ({
  applyAuthState: (response: Response) => response,
  supabase: {},
}) }));
vi.mock("@/lib/auth/verified-user", () => ({ getVerifiedUserId: async () => "a1000000-0000-4000-8000-000000000001" }));
vi.mock("@/lib/auth/team-context", () => ({ loadTeamContext: async () => ({ teamId: "a2000000-0000-4000-8000-000000000001", seasonId: "a3000000-0000-4000-8000-000000000001", seasonName: "Säsong" }) }));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient: () => ({ kind: "admin" }) }));
vi.mock("@/features/selections/manual-adjustment", () => ({ mutateManualAdjustment: mutate }));
import { POST } from "./route";

it("restores an exact manual pair through the server-only boundary", async () => {
  const matchId = "a5000000-0000-4000-8000-000000000001";
  const body = new URLSearchParams({ outgoingPlayerId: "a4000000-0000-4000-8000-000000000001", incomingPlayerId: "a4000000-0000-4000-8000-000000000002", fingerprint: "a".repeat(32) });
  const response = await POST(new NextRequest(`https://app.example/matches/${matchId}/adjust/restore`, { method: "POST", body }), { params: Promise.resolve({ id: matchId }) });
  expect(mutate).toHaveBeenCalledWith({ kind: "admin" }, "restore_manual_regular_adjustment", expect.objectContaining({ matchId }));
  expect(response.status).toBe(303);
  expect(response.headers.get("location")).toBe(`https://app.example/matches/${matchId}?adjustment=restored`);
});
