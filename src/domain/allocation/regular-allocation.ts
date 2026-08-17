import type { PlayerLevel } from "@/domain/player-level";

import type {
  AllocationError,
  AllocationPlayer,
  AllocationWarning,
  ManualSelection,
  MatchAllocation,
  RegularAllocationInput,
  RegularAllocationResult,
} from "./types";

type EligiblePlayer = AllocationPlayer & { level: PlayerLevel };

function duplicateValues(values: Array<string | number>): Set<string | number> {
  const seen = new Set<string | number>();
  const duplicates = new Set<string | number>();

  for (const value of values) {
    if (seen.has(value)) duplicates.add(value);
    seen.add(value);
  }

  return duplicates;
}

function validateInput(input: RegularAllocationInput): AllocationError[] {
  const errors: AllocationError[] = [];
  const playerIds = new Set(input.players.map(({ id }) => id));
  const matchIds = new Set(input.matches.map(({ id }) => id));

  if (duplicateValues(input.players.map(({ id }) => id)).size > 0) {
    errors.push({ code: "DUPLICATE_PLAYER_ID" });
  }
  if (duplicateValues(input.players.map(({ rotationOrder }) => rotationOrder)).size > 0) {
    errors.push({ code: "DUPLICATE_ROTATION_ORDER" });
  }
  if (duplicateValues(input.matches.map(({ id }) => id)).size > 0) {
    errors.push({ code: "DUPLICATE_MATCH_ID" });
  }
  if (duplicateValues(input.matches.map(({ order }) => order)).size > 0) {
    errors.push({ code: "DUPLICATE_MATCH_ORDER" });
  }

  for (const item of input.players) {
    if (!Number.isInteger(item.rotationOrder) || item.rotationOrder <= 0) {
      errors.push({ code: "INVALID_ROTATION_ORDER", playerId: item.id });
    }
    if (!Number.isInteger(item.baselineRegularCount) || item.baselineRegularCount < 0) {
      errors.push({ code: "INVALID_BASELINE_COUNT", playerId: item.id });
    }
    if (
      item.baselineLastRegularMatchOrder !== null &&
      (!Number.isInteger(item.baselineLastRegularMatchOrder) ||
        item.baselineLastRegularMatchOrder < 0)
    ) {
      errors.push({ code: "INVALID_MATCH_ORDER", playerId: item.id });
    }
  }

  for (const item of input.matches) {
    if (!Number.isInteger(item.order) || item.order < 0) {
      errors.push({ code: "INVALID_MATCH_ORDER", matchId: item.id });
    }
    if (!Number.isInteger(item.targetSize) || item.targetSize < 0) {
      errors.push({ code: "INVALID_TARGET_SIZE", matchId: item.id });
    }
  }

  const manualKeys = new Map<string, ManualSelection["decision"]>();
  for (const selection of input.manualSelections) {
    if (!matchIds.has(selection.matchId)) {
      errors.push({ code: "MANUAL_SELECTION_UNKNOWN_MATCH", matchId: selection.matchId });
    }
    if (!playerIds.has(selection.playerId)) {
      errors.push({ code: "MANUAL_SELECTION_UNKNOWN_PLAYER", playerId: selection.playerId });
    }

    const key = `${selection.matchId}\u0000${selection.playerId}`;
    const previous = manualKeys.get(key);
    if (previous && previous !== selection.decision) {
      errors.push({
        code: "CONFLICTING_MANUAL_SELECTION",
        matchId: selection.matchId,
        playerId: selection.playerId,
      });
    }
    manualKeys.set(key, selection.decision);
  }

  return errors;
}

function desiredLevelCounts(players: EligiblePlayer[], targetSize: number) {
  const counts = new Map<PlayerLevel, number>([
    [1, 0],
    [2, 0],
    [3, 0],
  ]);
  for (const item of players) counts.set(item.level, (counts.get(item.level) ?? 0) + 1);

  const shares = ([1, 2, 3] as PlayerLevel[]).map((level) => {
    const exact = players.length === 0 ? 0 : ((counts.get(level) ?? 0) * targetSize) / players.length;
    return { level, floor: Math.floor(exact), remainder: exact - Math.floor(exact) };
  });
  let remaining = targetSize - shares.reduce((sum, share) => sum + share.floor, 0);

  shares.sort((left, right) => right.remainder - left.remainder || left.level - right.level);
  for (const share of shares) {
    if (remaining <= 0) break;
    share.floor += 1;
    remaining -= 1;
  }

  return new Map(shares.map(({ level, floor }) => [level, floor]));
}

function waitingOrder(player: EligiblePlayer, lastSelectedOrder: Map<string, number | null>) {
  return (
    lastSelectedOrder.get(player.id) ??
    player.baselineLastRegularMatchOrder ??
    Number.MIN_SAFE_INTEGER
  );
}

export function generateRegularAllocation(
  input: RegularAllocationInput,
): RegularAllocationResult {
  const errors = validateInput(input);
  if (errors.length > 0) return { ok: false, errors };

  const validPlayers = input.players.filter(
    (item): item is EligiblePlayer => item.level === 1 || item.level === 2 || item.level === 3,
  );
  const excludedPlayerIds = input.players
    .filter((item) => item.level !== 1 && item.level !== 2 && item.level !== 3)
    .map(({ id }) => id)
    .sort();
  const warnings: AllocationWarning[] = excludedPlayerIds.length
    ? [{ code: "MISSING_PLAYER_LEVEL", playerIds: excludedPlayerIds }]
    : [];
  const playerById = new Map(validPlayers.map((item) => [item.id, item]));
  const ineligibleManualInclude = input.manualSelections.find(
    (selection) => selection.decision === "include" && !playerById.has(selection.playerId),
  );
  if (ineligibleManualInclude) {
    return {
      ok: false,
      errors: [
        {
          code: "MANUAL_SELECTION_INELIGIBLE_PLAYER",
          matchId: ineligibleManualInclude.matchId,
          playerId: ineligibleManualInclude.playerId,
        },
      ],
    };
  }
  const regularCounts = new Map(validPlayers.map((item) => [item.id, item.baselineRegularCount]));
  const lastSelectedOrder = new Map(
    validPlayers.map((item) => [item.id, item.baselineLastRegularMatchOrder]),
  );
  const allocations: MatchAllocation[] = [];

  for (const currentMatch of [...input.matches].sort((left, right) => left.order - right.order)) {
    const decisions = input.manualSelections.filter(
      (selection) => selection.matchId === currentMatch.id,
    );
    const includedIds = new Set(
      decisions.filter(({ decision }) => decision === "include").map(({ playerId }) => playerId),
    );
    const excludedIds = new Set(
      decisions.filter(({ decision }) => decision === "exclude").map(({ playerId }) => playerId),
    );
    const manualIncludes = [...includedIds]
      .map((id) => playerById.get(id))
      .filter((item): item is EligiblePlayer => item !== undefined);

    if (manualIncludes.length > currentMatch.targetSize) {
      return {
        ok: false,
        errors: [{ code: "TOO_MANY_MANUAL_INCLUDES", matchId: currentMatch.id }],
        warnings,
      };
    }

    const available = validPlayers.filter((item) => !excludedIds.has(item.id));
    if (currentMatch.targetSize > available.length) {
      return {
        ok: false,
        errors: [{ code: "NOT_ENOUGH_AVAILABLE_PLAYERS", matchId: currentMatch.id }],
        warnings,
      };
    }

    const selected = [...manualIncludes];
    const selectedIds = new Set(selected.map(({ id }) => id));
    const desiredByLevel = desiredLevelCounts(validPlayers, currentMatch.targetSize);
    const selectedByLevel = new Map<PlayerLevel, number>([
      [1, 0],
      [2, 0],
      [3, 0],
    ]);
    for (const item of selected) {
      selectedByLevel.set(item.level, (selectedByLevel.get(item.level) ?? 0) + 1);
    }

    while (selected.length < currentMatch.targetSize) {
      const candidates = available.filter((item) => !selectedIds.has(item.id));
      candidates.sort((left, right) => {
        const countDifference = (regularCounts.get(left.id) ?? 0) - (regularCounts.get(right.id) ?? 0);
        if (countDifference !== 0) return countDifference;

        const leftLevelFilled = (selectedByLevel.get(left.level) ?? 0) >= (desiredByLevel.get(left.level) ?? 0);
        const rightLevelFilled = (selectedByLevel.get(right.level) ?? 0) >= (desiredByLevel.get(right.level) ?? 0);
        if (leftLevelFilled !== rightLevelFilled) return leftLevelFilled ? 1 : -1;

        const waitDifference = waitingOrder(left, lastSelectedOrder) - waitingOrder(right, lastSelectedOrder);
        if (waitDifference !== 0) return waitDifference;
        return left.rotationOrder - right.rotationOrder;
      });

      const next = candidates[0];
      if (!next) {
        return {
          ok: false,
          errors: [{ code: "NOT_ENOUGH_AVAILABLE_PLAYERS", matchId: currentMatch.id }],
          warnings,
        };
      }
      selected.push(next);
      selectedIds.add(next.id);
      selectedByLevel.set(next.level, (selectedByLevel.get(next.level) ?? 0) + 1);
    }

    for (const item of selected) {
      regularCounts.set(item.id, (regularCounts.get(item.id) ?? 0) + 1);
      lastSelectedOrder.set(item.id, currentMatch.order);
    }

    const hasLevelDeviation = ([1, 2, 3] as PlayerLevel[]).some(
      (level) => (selectedByLevel.get(level) ?? 0) !== (desiredByLevel.get(level) ?? 0),
    );
    if (hasLevelDeviation) {
      warnings.push({ code: "LEVEL_BALANCE_DEVIATION", matchId: currentMatch.id });
    }

    allocations.push({
      matchId: currentMatch.id,
      playerIds: selected
        .sort((left, right) => left.rotationOrder - right.rotationOrder)
        .map(({ id }) => id),
    });
  }

  if (regularCounts.size > 0) {
    const totals = [...regularCounts.values()];
    const achievedDifference = Math.max(...totals) - Math.min(...totals);
    if (achievedDifference > 1) {
      warnings.push({ code: "FAIRNESS_DEVIATION", achievedDifference });
    }
  }

  return { ok: true, allocations, excludedPlayerIds, warnings };
}
