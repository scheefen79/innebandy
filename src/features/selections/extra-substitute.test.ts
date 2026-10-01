import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { loadExtraSubstituteSource, mutateExtraSubstitute, mutateExtraSubstitutes, parseExtraPlayerIds, shouldLoadExtraSubstituteSource } from "./extra-substitute";

describe("extra substitutes", () => {
  it("keeps remove available when target changed but blocks new extras", () => {
    expect(shouldLoadExtraSubstituteSource({ canAdjust: true, hasSavedRegularRoster: false, extraPlayerCount: 1 })).toBe(true);
    expect(shouldLoadExtraSubstituteSource({ canAdjust: true, hasSavedRegularRoster: false, extraPlayerCount: 0 })).toBe(false);
  });

  it("ranks canonical history without using player level", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { fingerprint: "fp", candidates: [
      { id: "later", firstName: "Sen", lastName: null, level: 1, rotationOrder: 1, completedExtraCount: 1, regularCount: 4, lastCompletedExtraAt: "2026-08-10T10:00:00Z" },
      { id: "none", firstName: "Ingen", lastName: "Historik", level: 3, rotationOrder: 2, completedExtraCount: 0, regularCount: 5, lastCompletedExtraAt: null },
      { id: "earlier", firstName: "Tidigare", lastName: null, level: 2, rotationOrder: 3, completedExtraCount: 1, regularCount: 4, lastCompletedExtraAt: "2026-08-01T10:00:00Z" },
    ] }, error: null });
    const result = await loadExtraSubstituteSource({ rpc } as unknown as SupabaseClient, "team", "season", "match");
    expect(result.candidates.map(({ id }) => id)).toEqual(["none", "earlier", "later"]);
    expect(result.candidates[0].recommended).toBe(true);
    expect(result.candidates[0].regularCount).toBe(5);
  });

  it("sends mutations only through the server client and maps safe errors", async () => {
    const input = { actorUserId: "coach", teamId: "team", seasonId: "season", matchId: "match", playerId: "player", fingerprint: "fp" };
    const okRpc = vi.fn().mockResolvedValue({ data: true, error: null });
    await expect(mutateExtraSubstitute({ rpc: okRpc } as unknown as SupabaseClient, "add_extra_substitute", input)).resolves.toBe("ok");
    expect(okRpc).toHaveBeenCalledWith("add_extra_substitute", {
      actor_user_id: "coach", target_team_id: "team", target_season_id: "season",
      target_match_id: "match", target_player_id: "player", expected_fingerprint: "fp",
    });
    const staleRpc = vi.fn().mockResolvedValue({ data: null, error: { message: "STALE_SELECTION" } });
    await expect(mutateExtraSubstitute({ rpc: staleRpc } as unknown as SupabaseClient, "remove_extra_substitute", input)).resolves.toBe("stale");
  });

  it("validates the extra batch and sends it to one server-only function", async () => {
    const ok = (value: string) => /^[a-z]$/.test(value);
    expect(parseExtraPlayerIds(["a", "b"], ok)).toEqual(["a", "b"]);
    expect(parseExtraPlayerIds([], ok)).toBeNull();
    expect(parseExtraPlayerIds(["a", "a"], ok)).toBeNull();
    expect(parseExtraPlayerIds(["a", "1"], ok)).toBeNull();
    const rpc = vi.fn().mockResolvedValue({ data: true, error: null });
    await expect(mutateExtraSubstitutes({ rpc } as unknown as SupabaseClient, { actorUserId: "coach", teamId: "team", seasonId: "season", matchId: "match", playerIds: ["a", "b"], fingerprint: "fp" })).resolves.toBe("ok");
    expect(rpc).toHaveBeenCalledWith("add_extra_substitutes", {
      actor_user_id: "coach", target_team_id: "team", target_season_id: "season", target_match_id: "match",
      target_player_ids: ["a", "b"], expected_fingerprint: "fp",
    });
    rpc.mockResolvedValue({ data: null, error: { message: "INVALID_EXTRA_SELECTION" } });
    await expect(mutateExtraSubstitutes({ rpc } as unknown as SupabaseClient, { actorUserId: "coach", teamId: "team", seasonId: "season", matchId: "match", playerIds: ["a"], fingerprint: "fp" })).resolves.toBe("invalid");
  });
});
