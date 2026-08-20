import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { loadAllocationPreview } from "./allocation-preview";

const source = {
  version: 1,
  players: [
    { id: "player-1", level: 1, rotationOrder: 1, baselineRegularCount: 0, baselineLastRegularMatchOrder: null },
    { id: "player-2", level: 2, rotationOrder: 2, baselineRegularCount: 0, baselineLastRegularMatchOrder: null },
  ],
  matches: [{ id: "match-1", order: 1, targetSize: 1 }],
  manualSelections: [],
};

describe("loadAllocationPreview", () => {
  it("maps the canonical database source into the deterministic engine", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { fingerprint: "abc", source }, error: null });
    const result = await loadAllocationPreview({ rpc } as unknown as SupabaseClient, "team-1", "season-1", "2026-08-20T10:00:00.000Z");
    expect(rpc).toHaveBeenCalledWith("get_regular_allocation_source", {
      target_team_id: "team-1", target_season_id: "season-1", boundary: "2026-08-20T10:00:00.000Z",
    });
    expect(result).toEqual({ ok: true, preview: {
      allocations: [{ matchId: "match-1", playerIds: ["player-1"] }],
      boundary: "2026-08-20T10:00:00.000Z", excludedPlayerIds: [], fingerprint: "abc", warnings: [],
    } });
  });

  it("returns domain errors without attempting persistence", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { fingerprint: "abc", source: { ...source, matches: [{ id: "match-1", order: 1, targetSize: 3 }] } }, error: null });
    await expect(loadAllocationPreview({ rpc } as unknown as SupabaseClient, "team-1", "season-1", "now")).resolves.toMatchObject({ ok: false, errors: [{ code: "NOT_ENOUGH_AVAILABLE_PLAYERS" }] });
  });
});
