import { expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const mutate = vi.hoisted(() => vi.fn().mockResolvedValue("ok"));
vi.mock("@/lib/supabase/route-handler", () => ({ createRouteHandlerClient: () => ({ applyAuthState: (response: Response) => response, supabase: {} }) }));
vi.mock("@/lib/auth/verified-user", () => ({ getVerifiedUserId: async () => "c1000000-0000-4000-8000-000000000001" }));
vi.mock("@/lib/auth/team-context", () => ({ loadTeamContext: async () => ({ teamId: "c2000000-0000-4000-8000-000000000001", seasonId: "c3000000-0000-4000-8000-000000000001", seasonName: "Säsong", role: "coach" }) }));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient: () => ({ kind: "admin" }) }));
vi.mock("@/features/selections/extra-substitute", async () => ({ mutateExtraSubstitutes: mutate, parseExtraPlayerIds: (await vi.importActual<typeof import("@/features/selections/extra-substitute")>("@/features/selections/extra-substitute")).parseExtraPlayerIds }));
import { POST } from "./route";

it("adds extra substitutes through the server-only boundary", async () => {
  const matchId = "c5000000-0000-4000-8000-000000000001";
  const playerId = "c4000000-0000-4000-8000-000000000002";
  const otherPlayerId = "c4000000-0000-4000-8000-000000000003";
  const response = await POST(new NextRequest(`https://app.example/matches/${matchId}/extras/add`, { method: "POST", body: new URLSearchParams([["playerId", playerId], ["playerId", otherPlayerId], ["fingerprint", "a".repeat(32)]]) }), { params: Promise.resolve({ id: matchId }) });
  expect(mutate).toHaveBeenCalledWith({ kind: "admin" }, expect.objectContaining({ matchId, playerIds: [playerId, otherPlayerId] }));
  expect(response.status).toBe(303);
  expect(response.headers.get("location")).toBe(`https://app.example/matches/${matchId}?extra=added`);
});

it("rejects duplicate and missing player ids before the mutation", async () => {
  mutate.mockClear();
  const matchId = "c5000000-0000-4000-8000-000000000001";
  const playerId = "c4000000-0000-4000-8000-000000000002";
  const send = (pairs: string[][]) => POST(new NextRequest(`https://app.example/matches/${matchId}/extras/add`, { method: "POST", body: new URLSearchParams([...pairs, ["fingerprint", "a".repeat(32)]]) }), { params: Promise.resolve({ id: matchId }) });
  expect((await send([["playerId", playerId], ["playerId", playerId]])).headers.get("location")).toContain("error=invalid");
  expect((await send([])).headers.get("location")).toContain("error=invalid");
  expect(mutate).not.toHaveBeenCalled();
});
