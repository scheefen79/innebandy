import type {
  AllocationMatch,
  AllocationPlayer,
  ExtraCandidate,
} from "./types";

export function player(
  id: string,
  overrides: Partial<AllocationPlayer> = {},
): AllocationPlayer {
  const numericId = Number(id.replace(/\D/g, "")) || 1;

  return {
    id,
    level: 2,
    rotationOrder: numericId,
    baselineRegularCount: 0,
    baselineLastRegularMatchOrder: null,
    ...overrides,
  };
}

export function match(
  id: string,
  overrides: Partial<AllocationMatch> = {},
): AllocationMatch {
  const numericId = Number(id.replace(/\D/g, "")) || 1;

  return {
    id,
    order: numericId,
    targetSize: 2,
    ...overrides,
  };
}

export function extraCandidate(
  id: string,
  overrides: Partial<ExtraCandidate> = {},
): ExtraCandidate {
  const numericId = Number(id.replace(/\D/g, "")) || 1;
  const completedExtraCount = overrides.completedExtraCount ?? 0;
  const lastCompletedExtraAt =
    "lastCompletedExtraAt" in overrides
      ? (overrides.lastCompletedExtraAt ?? null)
      : completedExtraCount > 0
        ? "2026-01-01T00:00:00Z"
        : null;

  return {
    id,
    completedExtraCount,
    lastCompletedExtraAt,
    rotationOrder: numericId,
    ...overrides,
  };
}
