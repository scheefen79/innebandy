import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { saveAllocation } from "./save-allocation";

const envelope = {
  fingerprint: "current",
  source: {
    version: 1,
    players: [{ id: "player-1", level: 1, rotationOrder: 1, baselineRegularCount: 0, baselineLastRegularMatchOrder: null }],
    matches: [{ id: "match-1", order: 1, targetSize: 1 }],
    manualSelections: [],
  },
};

describe("saveAllocation", () => {
  it("stops before the save RPC when the preview is stale", async () => {
    const userRpc = vi.fn().mockResolvedValueOnce({ data: envelope, error: null });
    const adminRpc = vi.fn();
    await expect(saveAllocation(
      { rpc: userRpc } as unknown as SupabaseClient,
      { rpc: adminRpc } as unknown as SupabaseClient,
      "coach-1", "team-1", "season-1", "now", "old",
    )).resolves.toEqual({ ok: false, error: "STALE_PREVIEW" });
    expect(userRpc).toHaveBeenCalledTimes(1);
    expect(adminRpc).not.toHaveBeenCalled();
  });

  it("reruns the engine and sends its current result to the atomic save RPC", async () => {
    const userRpc = vi.fn().mockResolvedValueOnce({ data: envelope, error: null });
    const adminRpc = vi.fn().mockResolvedValueOnce({ data: 1, error: null });
    await expect(saveAllocation(
      { rpc: userRpc } as unknown as SupabaseClient,
      { rpc: adminRpc } as unknown as SupabaseClient,
      "coach-1", "team-1", "season-1", "now", "current",
    )).resolves.toEqual({ ok: true, savedCount: 1 });
    expect(adminRpc).toHaveBeenLastCalledWith("save_regular_allocation", {
      actor_user_id: "coach-1",
      target_team_id: "team-1", target_season_id: "season-1", boundary: "now",
      expected_fingerprint: "current", allocations: [{ matchId: "match-1", playerIds: ["player-1"] }],
    });
  });
});
