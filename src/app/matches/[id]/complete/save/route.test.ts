import { NextRequest } from "next/server";
import { beforeEach, expect, it, vi } from "vitest";

const complete = vi.hoisted(() => vi.fn().mockResolvedValue("ok"));
vi.mock("@/lib/supabase/route-handler", () => ({ createRouteHandlerClient: () => ({ applyAuthState: (response: Response) => response, supabase: {} }) }));
vi.mock("@/lib/auth/verified-user", () => ({ getVerifiedUserId: async () => "d1000000-0000-4000-8000-000000000001" }));
vi.mock("@/lib/auth/team-context", () => ({ loadTeamContext: async () => ({ teamId: "d2000000-0000-4000-8000-000000000001", seasonId: "d3000000-0000-4000-8000-000000000001", seasonName: "Säsong", role: "coach" }) }));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient: () => ({ kind: "admin" }) }));
vi.mock("@/features/selections/match-completion", async (importOriginal) => ({ ...(await importOriginal<typeof import("@/features/selections/match-completion")>()), completeMatch: complete }));
import { POST } from "./route";

const matchId = "d5000000-0000-4000-8000-000000000001";
const playerA = "d4000000-0000-4000-8000-000000000001";
const playerB = "d4000000-0000-4000-8000-000000000002";

beforeEach(() => complete.mockReset().mockResolvedValue("ok"));

it("sends a complete boolean decision through the server-only boundary", async () => {
  const body = new URLSearchParams({ fingerprint: "a".repeat(32) });
  body.append("playerId", playerA); body.append("playerId", playerB); body.append("playedPlayerId", playerA);
  const response = await POST(new NextRequest(`https://app.example/matches/${matchId}/complete/save`, { method: "POST", body }), { params: Promise.resolve({ id: matchId }) });
  expect(complete).toHaveBeenCalledWith({ kind: "admin" }, expect.objectContaining({ matchId, participation: [{ playerId: playerA, played: true }, { playerId: playerB, played: false }] }));
  expect(response.status).toBe(303);
  expect(response.headers.get("location")).toBe(`https://app.example/matches/${matchId}?completion=saved`);
});

it("rejects duplicate or unknown player decisions before the database call", async () => {
  const body = new URLSearchParams({ fingerprint: "a".repeat(32) });
  body.append("playerId", playerA); body.append("playerId", playerA);
  const response = await POST(new NextRequest(`https://app.example/matches/${matchId}/complete/save`, { method: "POST", body }), { params: Promise.resolve({ id: matchId }) });
  expect(complete).not.toHaveBeenCalled();
  expect(response.headers.get("location")).toBe(`https://app.example/matches/${matchId}/complete?error=invalid`);
});

it("maps a stale completion to a recoverable Swedish form state", async () => {
  complete.mockResolvedValueOnce("stale");
  const body = new URLSearchParams({ fingerprint: "a".repeat(32), playerId: playerA, playedPlayerId: playerA });
  const response = await POST(new NextRequest(`https://app.example/matches/${matchId}/complete/save`, { method: "POST", body }), { params: Promise.resolve({ id: matchId }) });
  expect(response.headers.get("location")).toBe(`https://app.example/matches/${matchId}/complete?error=stale`);
});

it("shows the winning saved state when another coach completed first", async () => {
  complete.mockResolvedValueOnce("completed");
  const body = new URLSearchParams({ fingerprint: "a".repeat(32), playerId: playerA, playedPlayerId: playerA });
  const response = await POST(new NextRequest(`https://app.example/matches/${matchId}/complete/save`, { method: "POST", body }), { params: Promise.resolve({ id: matchId }) });
  expect(response.headers.get("location")).toBe(`https://app.example/matches/${matchId}?completion=conflict`);
});
