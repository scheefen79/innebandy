import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { buildParticipation, completeMatch, defaultPlayedPlayerIds, loadMatchCompletionSource, summarizeParticipation } from "./match-completion";

describe("match completion", () => {
  it("loads selected regular and extra participants", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { fingerprint: "fp", participants: [
      { playerId: "regular", firstName: "Ada", lastName: "A", selectionType: "regular", played: false },
      { playerId: "extra", firstName: "Bo", lastName: null, selectionType: "extra", played: false },
    ] }, error: null });
    const result = await loadMatchCompletionSource({ rpc } as unknown as SupabaseClient, "team", "season", "match");
    expect(result.participants).toEqual([
      { playerId: "regular", name: "Ada A", selectionType: "regular", played: false },
      { playerId: "extra", name: "Bo", selectionType: "extra", played: false },
    ]);
  });

  it("builds a full boolean decision and rejects duplicate or unknown ids", () => {
    expect(buildParticipation(["a", "b"], ["a"])).toEqual([{ playerId: "a", played: true }, { playerId: "b", played: false }]);
    expect(buildParticipation(["a", "a"], ["a"])).toBeNull();
    expect(buildParticipation(["a"], ["b"])).toBeNull();
  });

  it("defaults every selected participant to played and summarizes regular and extra separately", () => {
    const participants = [
      { playerId: "a", name: "A", selectionType: "regular" as const, played: false },
      { playerId: "b", name: "B", selectionType: "regular" as const, played: false },
      { playerId: "c", name: "C", selectionType: "extra" as const, played: false },
    ];
    expect(defaultPlayedPlayerIds(participants)).toEqual(["a", "b", "c"]);
    expect(summarizeParticipation(participants, ["a", "c"])).toEqual({ regularPlayed: 1, regularAbsent: 1, extraPlayed: 1, extraAbsent: 0 });
  });

  it("uses the server-only RPC and maps stable conflicts", async () => {
    const input = { actorUserId: "coach", teamId: "team", seasonId: "season", matchId: "match", fingerprint: "fp", participation: [{ playerId: "a", played: true }] };
    const rpc = vi.fn().mockResolvedValue({ data: true, error: null });
    await expect(completeMatch({ rpc } as unknown as SupabaseClient, input)).resolves.toBe("ok");
    expect(rpc).toHaveBeenCalledWith("complete_match", expect.objectContaining({ participation: input.participation }));
    const conflictRpc = vi.fn().mockResolvedValue({ data: null, error: { message: "MATCH_ALREADY_COMPLETED" } });
    await expect(completeMatch({ rpc: conflictRpc } as unknown as SupabaseClient, input)).resolves.toBe("completed");
  });
});
