import type { SupabaseClient } from "@supabase/supabase-js";
import { generateRegularAllocation } from "@/domain/allocation/regular-allocation";
import type {
  AllocationError,
  AllocationWarning,
  RegularAllocationInput,
} from "@/domain/allocation/types";

type AllocationSourceEnvelope = {
  fingerprint: string;
  source: RegularAllocationInput & { version: number };
};

export type AllocationPreview = {
  allocations: Array<{ matchId: string; playerIds: string[] }>;
  boundary: string;
  excludedPlayerIds: string[];
  fingerprint: string;
  warnings: AllocationWarning[];
};

export type AllocationPreviewResult =
  | { ok: true; preview: AllocationPreview }
  | { ok: false; errors: AllocationError[] };

function isEnvelope(value: unknown): value is AllocationSourceEnvelope {
  if (!value || typeof value !== "object") return false;
  const envelope = value as Partial<AllocationSourceEnvelope>;
  return typeof envelope.fingerprint === "string" && !!envelope.source &&
    envelope.source.version === 1 && Array.isArray(envelope.source.players) &&
    Array.isArray(envelope.source.matches) && Array.isArray(envelope.source.manualSelections);
}

export async function loadAllocationPreview(
  supabase: SupabaseClient,
  teamId: string,
  seasonId: string,
  boundary: string,
): Promise<AllocationPreviewResult> {
  const { data, error } = await supabase.rpc("get_regular_allocation_source", {
    target_team_id: teamId,
    target_season_id: seasonId,
    boundary,
  });
  if (error || !isEnvelope(data)) throw new Error("Det gick inte att skapa förhandsgranskningen.");

  const result = generateRegularAllocation(data.source);
  if (!result.ok) return result;
  return {
    ok: true,
    preview: {
      allocations: result.allocations,
      boundary,
      excludedPlayerIds: result.excludedPlayerIds,
      fingerprint: data.fingerprint,
      warnings: result.warnings,
    },
  };
}

export const allocationErrorText: Record<AllocationError["code"], string> = {
  CONFLICTING_MANUAL_SELECTION: "Två manuella beslut motsäger varandra.",
  DUPLICATE_MATCH_ID: "Matchunderlaget innehåller en dubblett.",
  DUPLICATE_MATCH_ORDER: "Matchordningen är inte entydig.",
  DUPLICATE_PLAYER_ID: "Spelarunderlaget innehåller en dubblett.",
  DUPLICATE_ROTATION_ORDER: "Två spelare har samma rotationsplats.",
  INVALID_BASELINE_COUNT: "Matchhistoriken innehåller ett ogiltigt antal.",
  INVALID_EXTRA_COUNT: "Historiken för extra inhopp är ogiltig.",
  INVALID_REGULAR_COUNT: "Historiken för ordinarie matcher är ogiltig.",
  INVALID_MATCH_ORDER: "Matchordningen är ogiltig.",
  INVALID_HISTORY_DATE: "Historiken innehåller ett ogiltigt datum.",
  INCONSISTENT_EXTRA_HISTORY: "Historiken för extra inhopp är inkonsekvent.",
  INVALID_ROTATION_ORDER: "En spelare saknar giltig rotationsplats.",
  INVALID_TARGET_SIZE: "En match har ett ogiltigt antal platser.",
  MANUAL_SELECTION_UNKNOWN_MATCH: "Ett manuellt val hör till en okänd match.",
  MANUAL_SELECTION_UNKNOWN_PLAYER: "Ett manuellt val gäller en okänd spelare.",
  MANUAL_SELECTION_INELIGIBLE_PLAYER: "En manuellt vald spelare kan inte tas ut.",
  NOT_ENOUGH_AVAILABLE_PLAYERS: "Det finns för få tillgängliga spelare för att fylla laget.",
  TOO_MANY_MANUAL_INCLUDES: "De manuella valen överstiger matchens antal platser.",
};

export function allocationWarningText(warning: AllocationWarning) {
  if (warning.code === "MISSING_PLAYER_LEVEL") return "Spelare utan giltig nivå har utelämnats.";
  if (warning.code === "LEVEL_BALANCE_DEVIATION") return "Nivåbalansen kunde inte uppnås fullt ut i en match.";
  return `Den minsta uppnådda skillnaden är ${warning.achievedDifference ?? "okänd"} matcher.`;
}
