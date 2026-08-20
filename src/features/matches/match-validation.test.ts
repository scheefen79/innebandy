import { describe, expect, it } from "vitest";
import { validateMatchInput } from "./match-validation";

const valid = {
  opponent: "  Täby FC  ", date: "2026-09-10", time: "18:30", location: "  Sporthallen  ",
  target_players: "", request_id: "550e8400-e29b-41d4-a716-446655440000",
};

describe("validateMatchInput", () => {
  it("normalizes input and uses the default target", () => {
    expect(validateMatchInput(valid, 8)).toEqual({ ok: true, value: {
      opponent: "Täby FC", startsAt: "2026-09-10T16:30:00.000Z", location: "Sporthallen",
      targetPlayers: 8, requestId: valid.request_id,
    } });
  });

  it("allows an explicit positive target when there are no active players", () => {
    expect(validateMatchInput({ ...valid, target_players: "4" }, null)).toMatchObject({ ok: true, value: { targetPlayers: 4 } });
  });

  it("rejects missing default, fractional target and invalid request id", () => {
    expect(validateMatchInput(valid, null).ok).toBe(false);
    expect(validateMatchInput({ ...valid, target_players: "2.5" }, 8).ok).toBe(false);
    expect(validateMatchInput({ ...valid, request_id: "not-a-uuid" }, 8).ok).toBe(false);
  });
});
