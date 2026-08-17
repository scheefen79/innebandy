import type {
  AllocationError,
  ExtraRecommendationInput,
  ExtraRecommendationResult,
} from "./types";

export function recommendExtraPlayers(
  input: ExtraRecommendationInput,
): ExtraRecommendationResult {
  const errors: AllocationError[] = [];
  const ids = new Set<string>();
  const rotations = new Set<number>();

  for (const candidate of input.eligibleCandidates) {
    if (ids.has(candidate.id)) errors.push({ code: "DUPLICATE_PLAYER_ID", playerId: candidate.id });
    if (rotations.has(candidate.rotationOrder)) {
      errors.push({ code: "DUPLICATE_ROTATION_ORDER", playerId: candidate.id });
    }
    if (!Number.isInteger(candidate.rotationOrder) || candidate.rotationOrder <= 0) {
      errors.push({ code: "INVALID_ROTATION_ORDER", playerId: candidate.id });
    }
    if (!Number.isInteger(candidate.completedExtraCount) || candidate.completedExtraCount < 0) {
      errors.push({ code: "INVALID_EXTRA_COUNT", playerId: candidate.id });
    }
    if (
      candidate.lastCompletedExtraAt !== null &&
      (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/.test(
        candidate.lastCompletedExtraAt,
      ) ||
        Number.isNaN(Date.parse(candidate.lastCompletedExtraAt)))
    ) {
      errors.push({ code: "INVALID_HISTORY_DATE", playerId: candidate.id });
    }
    if ((candidate.completedExtraCount === 0) !== (candidate.lastCompletedExtraAt === null)) {
      errors.push({ code: "INCONSISTENT_EXTRA_HISTORY", playerId: candidate.id });
    }
    ids.add(candidate.id);
    rotations.add(candidate.rotationOrder);
  }

  if (errors.length > 0) return { ok: false, errors };

  const candidateIds = [...input.eligibleCandidates]
    .sort((left, right) => {
      const countDifference = left.completedExtraCount - right.completedExtraCount;
      if (countDifference !== 0) return countDifference;

      if (left.lastCompletedExtraAt === null && right.lastCompletedExtraAt !== null) return -1;
      if (left.lastCompletedExtraAt !== null && right.lastCompletedExtraAt === null) return 1;
      if (left.lastCompletedExtraAt !== null && right.lastCompletedExtraAt !== null) {
        const dateDifference =
          Date.parse(left.lastCompletedExtraAt) - Date.parse(right.lastCompletedExtraAt);
        if (dateDifference !== 0) return dateDifference;
      }
      return left.rotationOrder - right.rotationOrder;
    })
    .map(({ id }) => id);

  return { ok: true, candidateIds };
}
