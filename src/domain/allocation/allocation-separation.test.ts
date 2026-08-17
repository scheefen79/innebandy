import { describe, expect, it } from "vitest";

import { recommendExtraPlayers } from "./extra-recommendation";
import { generateRegularAllocation } from "./regular-allocation";
import { extraCandidate, match, player } from "./test-builders";

describe("separata rättvisesystem", () => {
  it("låter inte ett genomfört extra inhopp påverka ordinarie fördelning", () => {
    const regularInput = {
      players: [player("p1"), player("p2")],
      matches: [match("m1", { targetSize: 1 })],
      manualSelections: [],
    };
    const beforeExtra = generateRegularAllocation(regularInput);

    expect(
      recommendExtraPlayers({
        eligibleCandidates: [
          extraCandidate("p1", { completedExtraCount: 1 }),
          extraCandidate("p2", { completedExtraCount: 0 }),
        ],
      }),
    ).toEqual({ ok: true, candidateIds: ["p2", "p1"] });

    expect(generateRegularAllocation(regularInput)).toEqual(beforeExtra);
  });

  it("låter inte ordinarie historik påverka extrarekommendationen", () => {
    const extraInput = {
      eligibleCandidates: [extraCandidate("p1"), extraCandidate("p2")],
    };
    const beforeRegular = recommendExtraPlayers(extraInput);

    generateRegularAllocation({
      players: [
        player("p1", { baselineRegularCount: 10 }),
        player("p2", { baselineRegularCount: 0 }),
      ],
      matches: [match("m1", { targetSize: 1 })],
      manualSelections: [],
    });

    expect(recommendExtraPlayers(extraInput)).toEqual(beforeRegular);
  });
});
