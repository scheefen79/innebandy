import { describe, expect, it } from "vitest";
import catalog from "../../../content/ovningsbanken-exercise-catalog.json";

describe("Övningsbankens katalog", () => {
  it("contains a complete, uniquely identified source inventory", () => {
    expect(catalog.exercises).toHaveLength(102);
    expect(new Set(catalog.exercises.map(exercise => exercise.id)).size).toBe(catalog.exercises.length);
    expect(catalog.failures).toEqual([]);
  });

  it("uses only verified source and media hosts", () => {
    for (const exercise of catalog.exercises) {
      expect(new URL(exercise.sourceUrl).hostname).toBe("www.innebandy.se");
      expect(new URL(exercise.sourceUrl).pathname).toMatch(/^\/ovningsbanken\//);
      if (exercise.sourceImageUrl) expect(new URL(exercise.sourceImageUrl).hostname).toBe("www.innebandy.se");
      if (exercise.sourceVideoUrl) expect(new URL(exercise.sourceVideoUrl).hostname).toBe("player.vimeo.com");
    }
  });
});
