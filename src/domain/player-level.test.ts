import { describe, expect, it } from "vitest";

import { getPlayerLevelLabel } from "./player-level";

describe("getPlayerLevelLabel", () => {
  it("beskriver nivåskalan med nivå 1 som högst", () => {
    expect(getPlayerLevelLabel(1)).toBe("Nivå 1 · Högst");
    expect(getPlayerLevelLabel(2)).toBe("Nivå 2 · Mellan");
    expect(getPlayerLevelLabel(3)).toBe("Nivå 3 · Lägst");
  });
});
