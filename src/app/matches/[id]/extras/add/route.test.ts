import { expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

const mutate = vi.hoisted(() => vi.fn().mockResolvedValue("ok"));
vi.mock("@/lib/supabase/route-handler", () => ({ createRouteHandlerClient: () => ({ applyAuthState: (response: Response) => response, supabase: { auth: { getClaims: async () => ({ data: { claims: { sub: "c1000000-0000-4000-8000-000000000001" } } }) } } }) }));
vi.mock("@/lib/auth/team-context", () => ({ loadTeamContext: async () => ({ teamId: "c2000000-0000-4000-8000-000000000001", seasonId: "c3000000-0000-4000-8000-000000000001", seasonName: "Säsong" }) }));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient: () => ({ kind: "admin" }) }));
vi.mock("@/features/selections/extra-substitute", () => ({ mutateExtraSubstitute: mutate }));
import { POST } from "./route";

it("adds an extra substitute through the server-only boundary", async () => {
  const matchId = "c5000000-0000-4000-8000-000000000001";
  const playerId = "c4000000-0000-4000-8000-000000000002";
  const response = await POST(new NextRequest(`https://app.example/matches/${matchId}/extras/add`, { method: "POST", body: new URLSearchParams({ playerId, fingerprint: "a".repeat(32) }) }), { params: Promise.resolve({ id: matchId }) });
  expect(mutate).toHaveBeenCalledWith({ kind: "admin" }, "add_extra_substitute", expect.objectContaining({ matchId, playerId }));
  expect(response.status).toBe(303);
  expect(response.headers.get("location")).toBe(`https://app.example/matches/${matchId}?extra=added`);
});
