import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { loadManualAdjustmentFingerprint, mutateManualAdjustment, mutateManualAdjustments, parseAdjustmentPairs } from "./manual-adjustment";

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

  it("parses outgoing/incoming pairs and rejects duplicates, missing and oversized batches", () => {
    const ok = (value: string) => /^[a-z]$/.test(value);
    const form = (outgoing: string[], incoming: Record<string, string>) => {
      const data = new FormData();
      outgoing.forEach((id) => data.append("outgoingPlayerId", id));
      Object.entries(incoming).forEach(([id, value]) => data.append(`incoming:${id}`, value));
      return data;
    };
    expect(parseAdjustmentPairs(form(["a", "b"], { a: "c", b: "d" }), ok)).toEqual([
      { outgoingPlayerId: "a", incomingPlayerId: "c" }, { outgoingPlayerId: "b", incomingPlayerId: "d" },
    ]);
    expect(parseAdjustmentPairs(form([], {}), ok)).toBeNull();
    expect(parseAdjustmentPairs(form(["a"], {}), ok)).toBeNull();
    expect(parseAdjustmentPairs(form(["a", "a"], { a: "c" }), ok)).toBeNull();
    expect(parseAdjustmentPairs(form(["a", "b"], { a: "c", b: "c" }), ok)).toBeNull();
    expect(parseAdjustmentPairs(form(["a", "b"], { a: "b", b: "c" }), ok)).toBeNull();
    const many = Array.from({ length: 21 }, (_, index) => `${index}`);
    expect(parseAdjustmentPairs(form(many, Object.fromEntries(many.map((id) => [id, `x${id}`]))), () => true)).toBeNull();
  });

  it("sends a whole batch to one server-only function", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: true, error: null });
    const pairs = [{ outgoingPlayerId: "a", incomingPlayerId: "c" }, { outgoingPlayerId: "b", incomingPlayerId: "d" }];
    await expect(mutateManualAdjustments({ rpc } as unknown as SupabaseClient, { actorUserId: "coach", teamId: "team", seasonId: "season", matchId: "match", pairs, fingerprint: "fp" })).resolves.toBe("ok");
    expect(rpc).toHaveBeenCalledWith("create_manual_regular_adjustments", {
      actor_user_id: "coach", target_team_id: "team", target_season_id: "season", target_match_id: "match",
      requested_adjustments: pairs, expected_fingerprint: "fp",
    });
    rpc.mockResolvedValue({ data: null, error: { message: "STALE_SELECTION" } });
    await expect(mutateManualAdjustments({ rpc } as unknown as SupabaseClient, { actorUserId: "coach", teamId: "team", seasonId: "season", matchId: "match", pairs, fingerprint: "fp" })).resolves.toBe("stale");
  });
});
