import { describe, expect, it } from "vitest";
import { getTeamBrand } from "./team-brand";

describe("getTeamBrand", () => {
  it("maps A and B variants to the same club logo", () => {
    expect(getTeamBrand("Täby FC (A)")?.logoSrc).toBe("/team-logos/taby-fc.png");
    expect(getTeamBrand("Täby FC (B)")?.logoSrc).toBe("/team-logos/taby-fc.png");
  });

  it("handles whitespace, casing and documented aliases", () => {
    expect(getTeamBrand("  VÄSBY AIK  ")?.name).toBe("Väsby AIK");
    expect(getTeamBrand("IBF Täby")?.logoSrc).toBe("/team-logos/taby-fc.png");
  });

  it("returns null for an unknown future opponent", () => {
    expect(getTeamBrand("Nytt lag")).toBeNull();
  });
});
