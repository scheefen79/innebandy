import { describe, expect, it } from "vitest";

import { match, player } from "./test-builders";
import { generateRegularAllocation } from "./regular-allocation";
import type { RegularAllocationInput } from "./types";

function expectSuccess(result: ReturnType<typeof generateRegularAllocation>) {
  expect(result.ok).toBe(true);
  if (!result.ok) throw new Error("Förväntade ett lyckat resultat.");
  return result;
}

function allocationCounts(allocations: Array<{ playerIds: string[] }>) {
  const counts = new Map<string, number>();
  for (const allocation of allocations) {
    for (const id of allocation.playerIds) counts.set(id, (counts.get(id) ?? 0) + 1);
  }
  return counts;
}

describe("generateRegularAllocation", () => {
  it("fördelar referensarkets 108 platser rättvist", () => {
    const players = Array.from({ length: 23 }, (_, index) =>
      player(`p${index + 1}`, {
        level: ((index % 3) + 1) as 1 | 2 | 3,
        rotationOrder: index + 1,
      }),
    );
    const matches = Array.from({ length: 9 }, (_, index) =>
      match(`m${index + 1}`, { order: index + 1, targetSize: 12 }),
    );

    const result = expectSuccess(
      generateRegularAllocation({ players, matches, manualSelections: [] }),
    );
    const counts = allocationCounts(result.allocations);

    expect(result.allocations).toHaveLength(9);
    expect(result.allocations.every(({ playerIds }) => playerIds.length === 12)).toBe(true);
    expect(
      result.allocations.every(({ playerIds }) => new Set(playerIds).size === playerIds.length),
    ).toBe(true);
    expect([...counts.values()].reduce((sum, count) => sum + count, 0)).toBe(108);
    expect([...counts.values()].every((count) => count === 4 || count === 5)).toBe(true);
    expect(Math.max(...counts.values()) - Math.min(...counts.values())).toBe(1);
  });

  it("behåller minsta möjliga skillnad i en matris av normala storlekar", () => {
    for (let playerCount = 2; playerCount <= 12; playerCount += 1) {
      for (let matchCount = 1; matchCount <= 8; matchCount += 1) {
        const targetSize = Math.max(1, Math.floor(playerCount / 2));
        const players = Array.from({ length: playerCount }, (_, index) =>
          player(`p${index + 1}`, {
            level: ((index % 3) + 1) as 1 | 2 | 3,
            rotationOrder: index + 1,
          }),
        );
        const matches = Array.from({ length: matchCount }, (_, index) =>
          match(`m${index + 1}`, { order: index + 1, targetSize }),
        );

        const result = expectSuccess(
          generateRegularAllocation({ players, matches, manualSelections: [] }),
        );
        const counts = players.map(
          ({ id }) => allocationCounts(result.allocations).get(id) ?? 0,
        );

        expect(result.allocations.every(({ playerIds }) => playerIds.length === targetSize)).toBe(
          true,
        );
        expect(Math.max(...counts) - Math.min(...counts)).toBeLessThanOrEqual(1);
      }
    }
  });

  it("låter inte en ojämn nivåfördelning påverka total rättvisa", () => {
    const players = [
      player("p1", { level: 1 }),
      player("p2", { level: 2 }),
      player("p3", { level: 2 }),
      player("p4", { level: 2 }),
      player("p5", { level: 3 }),
    ];
    const matches = Array.from({ length: 5 }, (_, index) =>
      match(`m${index + 1}`, { targetSize: 3 }),
    );

    const result = expectSuccess(
      generateRegularAllocation({ players, matches, manualSelections: [] }),
    );
    const totals = [...allocationCounts(result.allocations).values()];

    expect(Math.max(...totals) - Math.min(...totals)).toBe(0);
  });

  it("hanterar tomma listor samt en spelare och en match", () => {
    expect(
      generateRegularAllocation({ players: [], matches: [], manualSelections: [] }),
    ).toEqual({ ok: true, allocations: [], excludedPlayerIds: [], warnings: [] });

    expect(
      generateRegularAllocation({
        players: [player("p1")],
        matches: [match("m1", { targetSize: 1 })],
        manualSelections: [],
      }),
    ).toEqual({
      ok: true,
      allocations: [{ matchId: "m1", playerIds: ["p1"] }],
      excludedPlayerIds: [],
      warnings: [],
    });
  });

  it("använder längst väntetid före rotation vid lika matchantal", () => {
    const result = expectSuccess(
      generateRegularAllocation({
        players: [
          player("p1", {
            level: 2,
            baselineLastRegularMatchOrder: 8,
            rotationOrder: 1,
          }),
          player("p2", {
            level: 2,
            baselineLastRegularMatchOrder: 3,
            rotationOrder: 2,
          }),
        ],
        matches: [match("m10", { order: 10, targetSize: 1 })],
        manualSelections: [],
      }),
    );

    expect(result.allocations[0].playerIds).toEqual(["p2"]);
  });

  it("använder fast rotation som sista utslagsregel", () => {
    const result = expectSuccess(
      generateRegularAllocation({
        players: [
          player("z-player", { rotationOrder: 2 }),
          player("a-player", { rotationOrder: 1 }),
        ],
        matches: [match("m1", { targetSize: 1 })],
        manualSelections: [],
      }),
    );

    expect(result.allocations[0].playerIds).toEqual(["a-player"]);
  });

  it("ger identiskt resultat för identisk osorterad input utan att mutera den", () => {
    const input: RegularAllocationInput = {
      players: [player("p3"), player("p1"), player("p2")],
      matches: [match("m2"), match("m1")],
      manualSelections: [],
    };
    const snapshot = structuredClone(input);

    const first = generateRegularAllocation(input);
    const second = generateRegularAllocation(input);

    expect(first).toEqual(second);
    expect(input).toEqual(snapshot);
  });

  it("bevarar manuella tillägg och borttagningar", () => {
    const result = expectSuccess(
      generateRegularAllocation({
        players: [player("p1"), player("p2"), player("p3")],
        matches: [match("m1", { targetSize: 2 })],
        manualSelections: [
          { matchId: "m1", playerId: "p3", decision: "include" },
          { matchId: "m1", playerId: "p1", decision: "exclude" },
        ],
      }),
    );

    expect(result.allocations[0].playerIds).toContain("p3");
    expect(result.allocations[0].playerIds).not.toContain("p1");
  });

  it("använder baseline från frysta matcher men returnerar endast suffixet", () => {
    const result = expectSuccess(
      generateRegularAllocation({
        players: [
          player("p1", { baselineRegularCount: 2, rotationOrder: 1 }),
          player("p2", { baselineRegularCount: 0, rotationOrder: 2 }),
        ],
        matches: [match("m3", { order: 3, targetSize: 1 })],
        manualSelections: [],
      }),
    );

    expect(result.allocations).toEqual([{ matchId: "m3", playerIds: ["p2"] }]);
  });

  it("låter senaste frysta tilldelning avgöra väntetid vid lika baseline-count", () => {
    const result = expectSuccess(
      generateRegularAllocation({
        players: [
          player("p1", {
            baselineRegularCount: 1,
            baselineLastRegularMatchOrder: 2,
            rotationOrder: 1,
          }),
          player("p2", {
            baselineRegularCount: 1,
            baselineLastRegularMatchOrder: 1,
            rotationOrder: 2,
          }),
        ],
        matches: [match("m3", { order: 3, targetSize: 1 })],
        manualSelections: [],
      }),
    );

    expect(result.allocations).toEqual([{ matchId: "m3", playerIds: ["p2"] }]);
  });

  it("fyller från andra nivåer och varnar när en manuell exkludering bryter nivåkvoten", () => {
    const result = expectSuccess(
      generateRegularAllocation({
        players: [
          player("p1", { level: 1 }),
          player("p2", { level: 1 }),
          player("p3", { level: 2 }),
          player("p4", { level: 2 }),
        ],
        matches: [match("m1", { targetSize: 3 })],
        manualSelections: [{ matchId: "m1", playerId: "p2", decision: "exclude" }],
      }),
    );

    expect(result.allocations[0].playerIds).toHaveLength(3);
    expect(result.warnings).toContainEqual({ code: "LEVEL_BALANCE_DEVIATION", matchId: "m1" });
  });

  it("exkluderar spelare utan nivå och redovisar dem", () => {
    const result = expectSuccess(
      generateRegularAllocation({
        players: [player("p1", { level: null }), player("p2")],
        matches: [match("m1", { targetSize: 1 })],
        manualSelections: [],
      }),
    );

    expect(result.excludedPlayerIds).toEqual(["p1"]);
    expect(result.allocations[0].playerIds).toEqual(["p2"]);
    expect(result.warnings).toContainEqual({
      code: "MISSING_PLAYER_LEVEL",
      playerIds: ["p1"],
    });
  });

  it("stoppar atomiskt när target överstiger aktiva valbara spelare", () => {
    const result = generateRegularAllocation({
      players: [player("p1"), player("p2")],
      matches: [match("m1", { targetSize: 3 }), match("m2", { targetSize: 1 })],
      manualSelections: [],
    });

    expect(result).toEqual({
      ok: false,
      errors: [{ code: "NOT_ENOUGH_AVAILABLE_PLAYERS", matchId: "m1" }],
      warnings: [],
    });
    expect(result).not.toHaveProperty("allocations");
  });

  it("stoppar atomiskt när manuella borttagningar lämnar för få kandidater", () => {
    const result = generateRegularAllocation({
      players: [player("p1"), player("p2"), player("p3")],
      matches: [match("m1", { targetSize: 2 })],
      manualSelections: [
        { matchId: "m1", playerId: "p1", decision: "exclude" },
        { matchId: "m1", playerId: "p2", decision: "exclude" },
      ],
    });

    expect(result).toEqual({
      ok: false,
      errors: [{ code: "NOT_ENOUGH_AVAILABLE_PLAYERS", matchId: "m1" }],
      warnings: [],
    });
  });

  it("returnerar inget delresultat när en senare match är omöjlig", () => {
    const result = generateRegularAllocation({
      players: [player("p1"), player("p2")],
      matches: [match("m1", { targetSize: 1 }), match("m2", { targetSize: 2 })],
      manualSelections: [
        { matchId: "m2", playerId: "p1", decision: "exclude" },
        { matchId: "m2", playerId: "p2", decision: "exclude" },
      ],
    });

    expect(result.ok).toBe(false);
    expect(result).not.toHaveProperty("allocations");
  });

  it("avvisar okända manuella referenser och för många manuella tillägg", () => {
    const unknown = generateRegularAllocation({
      players: [player("p1")],
      matches: [match("m1", { targetSize: 1 })],
      manualSelections: [{ matchId: "unknown", playerId: "unknown", decision: "include" }],
    });
    expect(unknown.ok).toBe(false);
    if (unknown.ok) throw new Error("Förväntade valideringsfel.");
    expect(unknown.errors.map(({ code }) => code)).toEqual(
      expect.arrayContaining([
        "MANUAL_SELECTION_UNKNOWN_MATCH",
        "MANUAL_SELECTION_UNKNOWN_PLAYER",
      ]),
    );

    expect(
      generateRegularAllocation({
        players: [player("p1"), player("p2")],
        matches: [match("m1", { targetSize: 1 })],
        manualSelections: [
          { matchId: "m1", playerId: "p1", decision: "include" },
          { matchId: "m1", playerId: "p2", decision: "include" },
        ],
      }),
    ).toEqual({
      ok: false,
      errors: [{ code: "TOO_MANY_MANUAL_INCLUDES", matchId: "m1" }],
      warnings: [],
    });
  });

  it("redovisar nivåbrist även när den gör target omöjlig", () => {
    const result = generateRegularAllocation({
      players: [player("p1", { level: null }), player("p2")],
      matches: [match("m1", { targetSize: 2 })],
      manualSelections: [],
    });

    expect(result).toEqual({
      ok: false,
      errors: [{ code: "NOT_ENOUGH_AVAILABLE_PLAYERS", matchId: "m1" }],
      warnings: [{ code: "MISSING_PLAYER_LEVEL", playerIds: ["p1"] }],
    });
  });

  it("varnar när baseline och manuella beslut gör slutresultatet ojämnt", () => {
    const result = expectSuccess(
      generateRegularAllocation({
        players: [
          player("p1", { baselineRegularCount: 3 }),
          player("p2", { baselineRegularCount: 0 }),
        ],
        matches: [match("m1", { targetSize: 1 })],
        manualSelections: [{ matchId: "m1", playerId: "p1", decision: "include" }],
      }),
    );

    expect(result.warnings).toContainEqual({
      code: "FAIRNESS_DEVIATION",
      achievedDifference: 4,
    });
  });

  it("avvisar manuellt inkluderad spelare utan giltig nivå", () => {
    const result = generateRegularAllocation({
      players: [player("p1", { level: null }), player("p2")],
      matches: [match("m1", { targetSize: 1 })],
      manualSelections: [{ matchId: "m1", playerId: "p1", decision: "include" }],
    });

    expect(result).toEqual({
      ok: false,
      errors: [
        { code: "MANUAL_SELECTION_INELIGIBLE_PLAYER", matchId: "m1", playerId: "p1" },
      ],
    });
  });

  it("avvisar motstridiga manuella beslut", () => {
    const result = generateRegularAllocation({
      players: [player("p1")],
      matches: [match("m1", { targetSize: 1 })],
      manualSelections: [
        { matchId: "m1", playerId: "p1", decision: "include" },
        { matchId: "m1", playerId: "p1", decision: "exclude" },
      ],
    });

    expect(result).toEqual({
      ok: false,
      errors: [
        { code: "CONFLICTING_MANUAL_SELECTION", matchId: "m1", playerId: "p1" },
      ],
    });
  });

  it("avvisar dubbletter och ogiltiga numeriska värden", () => {
    const result = generateRegularAllocation({
      players: [
        player("p1", { rotationOrder: 0, baselineRegularCount: -1 }),
        player("p1", { rotationOrder: 0 }),
      ],
      matches: [match("m1", { order: -1, targetSize: -1 }), match("m1", { order: -1 })],
      manualSelections: [],
    });

    expect(result.ok).toBe(false);
    if (result.ok) throw new Error("Förväntade valideringsfel.");
    expect(result.errors.map(({ code }) => code)).toEqual(
      expect.arrayContaining([
        "DUPLICATE_PLAYER_ID",
        "DUPLICATE_ROTATION_ORDER",
        "DUPLICATE_MATCH_ID",
        "DUPLICATE_MATCH_ORDER",
        "INVALID_ROTATION_ORDER",
        "INVALID_BASELINE_COUNT",
        "INVALID_MATCH_ORDER",
        "INVALID_TARGET_SIZE",
      ]),
    );
  });
});
