import { describe, expect, it } from "vitest";
import { candidateAreaText, getReplacementCandidate, hasValidCatalogReplacements, isCatalogReplacementPayload, preferredExerciseMedia, replacementCandidates } from "./exercise-catalog";
import type { TrainingItem, TrainingPlan } from "./training-plans";

const technique: TrainingItem = { id: "item", section: "technique", position: 1, title: "Passa", guideMinutes: 10, purpose: null, instructions: null, coachingPoints: [], sourceUrl: "https://www.innebandy.se/ovningsbanken/dragpassningar", sourceImageUrl: null };
const match: TrainingItem = { ...technique, section: "match_exercise", sourceUrl: "https://www.innebandy.se/ovningsbanken/pressa-pressen" };

describe("replacementCandidates", () => {
  it("keeps replacements in the current block area and section", () => {
    const candidates = replacementCandidates({ item: technique, themeBlock: 1 });
    expect(candidates.length).toBeGreaterThan(0);
    expect(candidates.every(candidate => candidate.levels.includes("Blå 9-12 år"))).toBe(true);
    expect(candidates.every(candidate => candidate.themes.includes("Teknikträning"))).toBe(true);
    expect(candidates.every(candidate => candidate.skills.some(skill => ["Passning/mottagning", "Spelbarhet"].includes(skill)))).toBe(true);
    expect(candidates.some(candidate => candidate.sourceUrl === technique.sourceUrl)).toBe(false);
  });

  it("does not put technique exercises in a match-exercise slot", () => {
    const candidates = replacementCandidates({ item: match, themeBlock: 4 });
    expect(candidates.length).toBeGreaterThan(0);
    expect(candidates.every(candidate => !candidate.themes.includes("Teknikträning"))).toBe(true);
    expect(candidates.every(candidate => candidate.skills.some(skill => ["Pressa", "Markera", "Duellspel", "Defensiv sortering"].includes(skill)))).toBe(true);
  });

  it("explains the matching area from the current exercise", () => {
    expect(candidateAreaText(technique, 1)).toBe("Passning/mottagning");
  });

  it("does not suggest an area when the current source is unverified", () => {
    expect(replacementCandidates({ item: { ...technique, sourceUrl: "https://example.test/unknown" }, themeBlock: 1 })).toEqual([]);
  });

  it("prioritizes verified video, then a non-placeholder image, then no media", () => {
    const withVideo = preferredExerciseMedia("https://innebandy.se/ovningsbanken/dragpassningar", "https://innebandy.se/media/fallback.png");
    expect(withVideo.sourceVideoUrl).toMatch(/^https:\/\/player\.vimeo\.com\//);
    expect(withVideo.sourceImageUrl).toMatch(/^https:\/\/www\.innebandy\.se\/media\//);
    expect(preferredExerciseMedia("https://example.test/unknown", null)).toEqual({ sourceVideoUrl: null, sourceImageUrl: null });
  });

  it("recognizes only an unchanged catalog replacement payload", () => {
    const candidate = getReplacementCandidate({ item: technique, themeBlock: 1, catalogId: replacementCandidates({ item: technique, themeBlock: 1 })[0].id });
    expect(candidate).toBeTruthy();
    expect(isCatalogReplacementPayload({ item: { title: candidate!.title, sourceTitle: candidate!.title, sourceUrl: candidate!.sourceUrl, sourceImageUrl: candidate!.sourceImageUrl, purpose: candidate!.summary, instructions: null, coachingPoints: [] }, candidate: candidate! })).toBe(true);
    expect(isCatalogReplacementPayload({ item: { title: "Ändrad", sourceTitle: candidate!.title, sourceUrl: candidate!.sourceUrl, sourceImageUrl: candidate!.sourceImageUrl, purpose: candidate!.summary, instructions: null, coachingPoints: [] }, candidate: candidate! })).toBe(false);
  });

  it("rejects a catalog replacement that is not valid for the stored item", () => {
    const candidate = replacementCandidates({ item: technique, themeBlock: 1 })[0];
    const plan: TrainingPlan = { id: "training", startsAt: "2026-09-05T08:00:00Z", endsAt: "2026-09-05T09:00:00Z", themeBlock: 1, focus: "Passning", keyMessage: "PASSA", status: "draft", revision: 1, updatedAt: "2026-09-01T08:00:00Z", updatedBy: "coach", coachNotes: null, items: [technique] };
    const replacement = { clientItemId: "item", replacementCatalogId: candidate.id, title: candidate.title, sourceTitle: candidate.title, sourceUrl: candidate.sourceUrl, sourceImageUrl: candidate.sourceImageUrl, purpose: candidate.summary, instructions: null, coachingPoints: [] };
    expect(hasValidCatalogReplacements([replacement], plan)).toBe(true);
    expect(hasValidCatalogReplacements([{ ...replacement, title: "Fel övning" }], plan)).toBe(false);
    expect(hasValidCatalogReplacements([{ ...replacement, clientItemId: "other" }], plan)).toBe(false);
    expect(hasValidCatalogReplacements([{ clientItemId: "item", title: "Manuell", sourceUrl: "https://innebandy.se/ovningsbanken/handledsskott", sourceTitle: null, sourceImageUrl: null }], plan)).toBe(false);
    expect(hasValidCatalogReplacements([{ clientItemId: "item", title: "Manuell", sourceUrl: "https://innebandy.se/ovningsbanken/handledsskott", sourceTitle: null, sourceImageUrl: null, sourceChangeMode: "manual" }], plan)).toBe(true);
  });
});
