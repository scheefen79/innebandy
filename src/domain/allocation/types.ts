import type { PlayerLevel } from "@/domain/player-level";

export type AllocationPlayer = {
  id: string;
  level: PlayerLevel | null;
  rotationOrder: number;
  baselineRegularCount: number;
  baselineLastRegularMatchOrder: number | null;
};

export type AllocationMatch = {
  id: string;
  order: number;
  targetSize: number;
};

export type ManualSelection = {
  matchId: string;
  playerId: string;
  decision: "include" | "exclude";
};

export type RegularAllocationInput = {
  players: AllocationPlayer[];
  matches: AllocationMatch[];
  manualSelections: ManualSelection[];
};

export type MatchAllocation = {
  matchId: string;
  playerIds: string[];
};

export type AllocationWarningCode =
  | "FAIRNESS_DEVIATION"
  | "LEVEL_BALANCE_DEVIATION"
  | "MISSING_PLAYER_LEVEL";

export type AllocationWarning = {
  achievedDifference?: number;
  code: AllocationWarningCode;
  matchId?: string;
  playerIds?: string[];
};

export type AllocationErrorCode =
  | "CONFLICTING_MANUAL_SELECTION"
  | "DUPLICATE_MATCH_ID"
  | "DUPLICATE_MATCH_ORDER"
  | "DUPLICATE_PLAYER_ID"
  | "DUPLICATE_ROTATION_ORDER"
  | "INVALID_BASELINE_COUNT"
  | "INVALID_EXTRA_COUNT"
  | "INVALID_MATCH_ORDER"
  | "INVALID_HISTORY_DATE"
  | "INCONSISTENT_EXTRA_HISTORY"
  | "INVALID_ROTATION_ORDER"
  | "INVALID_TARGET_SIZE"
  | "MANUAL_SELECTION_UNKNOWN_MATCH"
  | "MANUAL_SELECTION_UNKNOWN_PLAYER"
  | "MANUAL_SELECTION_INELIGIBLE_PLAYER"
  | "NOT_ENOUGH_AVAILABLE_PLAYERS"
  | "TOO_MANY_MANUAL_INCLUDES";

export type AllocationError = {
  code: AllocationErrorCode;
  matchId?: string;
  playerId?: string;
};

export type RegularAllocationResult =
  | {
      ok: true;
      allocations: MatchAllocation[];
      excludedPlayerIds: string[];
      warnings: AllocationWarning[];
    }
  | {
      ok: false;
      errors: AllocationError[];
      warnings?: AllocationWarning[];
    };

export type ExtraCandidate = {
  id: string;
  completedExtraCount: number;
  lastCompletedExtraAt: string | null;
  rotationOrder: number;
};

export type ExtraRecommendationInput = {
  eligibleCandidates: ExtraCandidate[];
};

export type ExtraRecommendationResult =
  | {
      ok: true;
      candidateIds: string[];
    }
  | {
      ok: false;
      errors: AllocationError[];
    };
