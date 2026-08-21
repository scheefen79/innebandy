import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { loadManualAdjustmentFingerprint, mutateManualAdjustment } from "./manual-adjustment";

describe("manual adjustment", () => {
  it("loads a server-computed match fingerprint", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { fingerprint: "abc", source: { match: {} } }, error: null });
    await expect(loadManualAdjustmentFingerprint({ rpc } as unknown as SupabaseClient, "team", "season", "match")).resolves.toBe("abc");
    expect(rpc).toHaveBeenCalledWith("get_manual_adjustment_source", {
      target_team_id: "team", target_season_id: "season", target_match_id: "match",
    });
  });

  it("uses only the server client for a create mutation", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: true, error: null });
    await expect(mutateManualAdjustment(
      { rpc } as unknown as SupabaseClient,
      "create_manual_regular_adjustment",
      { actorUserId: "coach", teamId: "team", seasonId: "season", matchId: "match", outgoingPlayerId: "out", incomingPlayerId: "in", fingerprint: "fp" },
    )).resolves.toBe("ok");
    expect(rpc).toHaveBeenCalledWith("create_manual_regular_adjustment", {
      actor_user_id: "coach", target_team_id: "team", target_season_id: "season", target_match_id: "match",
      outgoing_player_id: "out", incoming_player_id: "in", expected_fingerprint: "fp",
    });
  });

  it("maps stale and invalid database errors without leaking details", async () => {
    const input = { actorUserId: "coach", teamId: "team", seasonId: "season", matchId: "match", outgoingPlayerId: "out", incomingPlayerId: "in", fingerprint: "fp" };
    const staleRpc = vi.fn().mockResolvedValue({ data: null, error: { message: "STALE_SELECTION" } });
    const invalidRpc = vi.fn().mockResolvedValue({ data: null, error: { message: "INVALID_ADJUSTMENT" } });
    await expect(mutateManualAdjustment({ rpc: staleRpc } as unknown as SupabaseClient, "restore_manual_regular_adjustment", input)).resolves.toBe("stale");
    await expect(mutateManualAdjustment({ rpc: invalidRpc } as unknown as SupabaseClient, "restore_manual_regular_adjustment", input)).resolves.toBe("invalid");
  });
});
