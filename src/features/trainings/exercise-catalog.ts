import catalog from "../../../content/ovningsbanken-exercise-catalog.json";
import type { TrainingItem, TrainingPlan, TrainingSection } from "./training-plans";

export type ExerciseCatalogItem = {
  id: string;
  title: string;
  sourceUrl: string;
  sourceImageUrl: string | null;
  sourceVideoUrl: string | null;
  summary: string | null;
  themes: string[];
  skills: string[];
  levels: string[];
};

const exercises = catalog.exercises as ExerciseCatalogItem[];
const blueLevel = "Blå 9-12 år";

const blockAreas: Record<number, string[]> = {
  1: ["Passning/mottagning", "Spelbarhet"],
  2: ["Bollbehandling", "Driva boll", "Utmana/dribbla", "Vända med boll"],
  3: ["Avslut"],
  4: ["Pressa", "Markera", "Duellspel", "Defensiv sortering"],
  5: ["Passning/mottagning", "Spelbarhet", "Bollbehandling", "Driva boll", "Utmana/dribbla", "Vända med boll", "Avslut", "Pressa", "Markera", "Duellspel", "Defensiv sortering"]
};

function isCompatibleSection(exercise: ExerciseCatalogItem, section: TrainingSection) {
  if (section === "technique") return exercise.themes.includes("Teknikträning");
  if (section === "match_exercise") return !exercise.themes.includes("Teknikträning") && !exercise.themes.includes("Fysträning") && !exercise.themes.includes("Lek");
  return false;
}

function sharedAreas(source: ExerciseCatalogItem | undefined, block: number) {
  if (!source) return [];
  const allowed = blockAreas[block] ?? [];
  return source.skills.filter(skill => allowed.includes(skill));
}

function canonicalSourceUrl(sourceUrl: string | null) {
  return sourceUrl?.replace("https://www.innebandy.se/", "https://innebandy.se/") ?? null;
}

export function getCatalogExercise(sourceUrl: string | null) {
  const canonical = canonicalSourceUrl(sourceUrl);
  return exercises.find(exercise => canonicalSourceUrl(exercise.sourceUrl) === canonical);
}

export function replacementCandidates({ item, themeBlock }: { item: TrainingItem; themeBlock: number }) {
  const source = getCatalogExercise(item.sourceUrl);
  const areas = sharedAreas(source, themeBlock);
  return exercises
    .filter(exercise => canonicalSourceUrl(exercise.sourceUrl) !== canonicalSourceUrl(item.sourceUrl))
    .filter(exercise => exercise.levels.includes(blueLevel))
    .filter(exercise => isCompatibleSection(exercise, item.section))
    .filter(exercise => exercise.skills.some(skill => areas.includes(skill)))
    .sort((left, right) => left.title.localeCompare(right.title, "sv"));
}

export function candidateAreaText(item: TrainingItem, themeBlock: number) {
  return sharedAreas(getCatalogExercise(item.sourceUrl), themeBlock).join(" · ");
}

export function getReplacementCandidate({ item, themeBlock, catalogId }: { item: TrainingItem; themeBlock: number; catalogId: string }) {
  return replacementCandidates({ item, themeBlock }).find(candidate => candidate.id === catalogId) ?? null;
}

export function isCatalogReplacementPayload({ item, candidate }: { item: Record<string, unknown>; candidate: ExerciseCatalogItem }) {
  const text = (value: unknown) => typeof value === "string" ? value : "";
  const nullableText = (value: unknown) => value === null || value === "" ? null : text(value);
  const points = Array.isArray(item.coachingPoints) ? item.coachingPoints : [];
  return text(item.title) === candidate.title
    && nullableText(item.sourceTitle) === candidate.title
    && canonicalSourceUrl(nullableText(item.sourceUrl)) === canonicalSourceUrl(candidate.sourceUrl)
    && nullableText(item.sourceImageUrl) === candidate.sourceImageUrl
    && nullableText(item.purpose) === candidate.summary
    && nullableText(item.instructions) === null
    && points.length === 0;
}

export function hasValidCatalogReplacements(items: unknown[], existing: TrainingPlan) {
  for (const value of items) {
    if (!value || typeof value !== "object") return false;
    const item = value as Record<string, unknown>;
    const catalogId = item.replacementCatalogId;
    const clientItemId = item.clientItemId;
    const previous = typeof clientItemId === "string" ? existing.items.find(candidate => candidate.id === clientItemId) : undefined;
    const sourceChanged = previous && (canonicalSourceUrl(typeof item.sourceUrl === "string" ? item.sourceUrl : null) !== canonicalSourceUrl(previous.sourceUrl)
      || (typeof item.sourceTitle === "string" ? item.sourceTitle : null) !== (previous.sourceTitle ?? null)
      || (typeof item.sourceImageUrl === "string" ? item.sourceImageUrl : null) !== previous.sourceImageUrl);
    if (catalogId == null) {
      if (sourceChanged && item.sourceChangeMode !== "manual") return false;
      continue;
    }
    if (typeof catalogId !== "string" || !previous) return false;
    const replacement = getReplacementCandidate({ item: previous, themeBlock: existing.themeBlock, catalogId });
    if (!replacement || !isCatalogReplacementPayload({ item, candidate: replacement })) return false;
  }
  return true;
}
