import { describe, expect, it } from "vitest";

import { recommendExtraPlayers } from "./extra-recommendation";
import { extraCandidate } from "./test-builders";

describe("recommendExtraPlayers", () => {
  it("prioriterar färst genomförda extra inhopp", () => {
    const result = recommendExtraPlayers({
      eligibleCandidates: [
        extraCandidate("p1", { completedExtraCount: 1 }),
        extraCandidate("p2", { completedExtraCount: 0 }),
        extraCandidate("p3", { completedExtraCount: 2 }),
      ],
    });

    expect(result).toEqual({ ok: true, candidateIds: ["p2", "p1", "p3"] });
  });

  it("prioriterar den som väntat längst vid lika antal", () => {
    const result = recommendExtraPlayers({
      eligibleCandidates: [
        extraCandidate("p1", {
          completedExtraCount: 1,
          lastCompletedExtraAt: "2026-08-10T10:00:00Z",
        }),
        extraCandidate("p2", {
          completedExtraCount: 1,
          lastCompletedExtraAt: "2026-07-10T10:00:00Z",
        }),
      ],
    });

    expect(result).toEqual({ ok: true, candidateIds: ["p2", "p1"] });
  });

  it("behandlar ingen tidigare extramatch som längst väntetid", () => {
    const result = recommendExtraPlayers({
      eligibleCandidates: [
        extraCandidate("p1", {
          completedExtraCount: 1,
          lastCompletedExtraAt: "2026-07-10T10:00:00Z",
        }),
        extraCandidate("p2", { lastCompletedExtraAt: null }),
      ],
    });

    expect(result).toEqual({ ok: true, candidateIds: ["p2", "p1"] });
  });

  it("jämför blandad sekundprecision kronologiskt", () => {
    const result = recommendExtraPlayers({
      eligibleCandidates: [
        extraCandidate("p1", {
          completedExtraCount: 1,
          lastCompletedExtraAt: "2026-08-10T10:00:00.1Z",
        }),
        extraCandidate("p2", {
          completedExtraCount: 1,
          lastCompletedExtraAt: "2026-08-10T10:00:00Z",
        }),
      ],
    });

    expect(result).toEqual({ ok: true, candidateIds: ["p2", "p1"] });
  });

  it("använder fast rotation som sista utslagsregel och muterar inte input", () => {
    const eligibleCandidates = [
      extraCandidate("z-player", { rotationOrder: 2 }),
      extraCandidate("a-player", { rotationOrder: 1 }),
    ];
    const snapshot = structuredClone(eligibleCandidates);

    const result = recommendExtraPlayers({ eligibleCandidates });

    expect(result).toEqual({ ok: true, candidateIds: ["a-player", "z-player"] });
    expect(eligibleCandidates).toEqual(snapshot);
  });

  it("rangordnar endast kandidater som applikationslagret skickar in", () => {
    const result = recommendExtraPlayers({
      eligibleCandidates: [extraCandidate("eligible-player")],
    });

    expect(result).toEqual({ ok: true, candidateIds: ["eligible-player"] });
  });

  it("hanterar en tom kandidatlista", () => {
    expect(recommendExtraPlayers({ eligibleCandidates: [] })).toEqual({
      ok: true,
      candidateIds: [],
    });
  });

  it("avvisar dubbletter och ogiltig historik", () => {
    const result = recommendExtraPlayers({
      eligibleCandidates: [
        extraCandidate("p1", {
          completedExtraCount: -1,
          lastCompletedExtraAt: "inte-ett-datum",
          rotationOrder: 0,
        }),
        extraCandidate("p1", { rotationOrder: 0 }),
      ],
    });

    expect(result.ok).toBe(false);
    if (result.ok) throw new Error("Förväntade valideringsfel.");
    expect(result.errors.map(({ code }) => code)).toEqual(
      expect.arrayContaining([
        "DUPLICATE_PLAYER_ID",
        "DUPLICATE_ROTATION_ORDER",
        "INVALID_EXTRA_COUNT",
        "INVALID_HISTORY_DATE",
        "INVALID_ROTATION_ORDER",
      ]),
    );
  });

  it("avvisar historik där count och senaste datum inte kan stämma samtidigt", () => {
    const result = recommendExtraPlayers({
      eligibleCandidates: [
        extraCandidate("p1", { completedExtraCount: 1, lastCompletedExtraAt: null }),
        extraCandidate("p2", {
          completedExtraCount: 0,
          lastCompletedExtraAt: "2026-08-10T10:00:00Z",
        }),
      ],
    });

    expect(result.ok).toBe(false);
    if (result.ok) throw new Error("Förväntade historikfel.");
    expect(result.errors).toEqual([
      { code: "INCONSISTENT_EXTRA_HISTORY", playerId: "p1" },
      { code: "INCONSISTENT_EXTRA_HISTORY", playerId: "p2" },
    ]);
  });
});
