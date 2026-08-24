import type { SupabaseClient } from "@supabase/supabase-js";
import { recommendExtraPlayers } from "@/domain/allocation/extra-recommendation";

export type ExtraSubstituteCandidate = {
  id: string;
  name: string;
  completedExtraCount: number;
  regularCount: number;
  lastCompletedExtraAt: string | null;
  recommended: boolean;
};

export function shouldLoadExtraSubstituteSource(input: {
  canAdjust: boolean;
  hasSavedRegularRoster: boolean;
  extraPlayerCount: number;
}): boolean {
  return input.canAdjust && (input.hasSavedRegularRoster || input.extraPlayerCount > 0);
}

type RawCandidate = {
  id?: unknown;
  firstName?: unknown;
  lastName?: unknown;
  rotationOrder?: unknown;
  completedExtraCount?: unknown;
  regularCount?: unknown;
  lastCompletedExtraAt?: unknown;
};

export async function loadExtraSubstituteSource(
  supabase: SupabaseClient,
  teamId: string,
  seasonId: string,
  matchId: string,
): Promise<{ fingerprint: string; candidates: ExtraSubstituteCandidate[] }> {
  const { data, error } = await supabase.rpc("get_extra_substitute_source", {
    target_team_id: teamId,
    target_season_id: seasonId,
    target_match_id: matchId,
  });
  if (error) throw new Error("Det gick inte att hämta extra kandidater.");
  const envelope = data as { fingerprint?: unknown; candidates?: unknown } | null;
  if (!envelope || typeof envelope.fingerprint !== "string" || !Array.isArray(envelope.candidates)) {
    throw new Error("Underlaget för extra inhoppare är ogiltigt.");
  }
  const raw = envelope.candidates as RawCandidate[];
  const ranking = recommendExtraPlayers({
    eligibleCandidates: raw.map((candidate) => ({
      id: String(candidate.id ?? ""),
      rotationOrder: Number(candidate.rotationOrder),
      completedExtraCount: Number(candidate.completedExtraCount),
      regularCount: Number(candidate.regularCount),
      lastCompletedExtraAt: candidate.lastCompletedExtraAt === null ? null : String(candidate.lastCompletedExtraAt ?? ""),
    })),
  });
  if (!ranking.ok) throw new Error("Historiken för extra inhoppare är ogiltig.");
  const byId = new Map(raw.map((candidate) => [String(candidate.id), candidate]));
  return {
    fingerprint: envelope.fingerprint,
    candidates: ranking.candidateIds.map((id, index) => {
      const candidate = byId.get(id)!;
      return {
        id,
        name: [candidate.firstName, candidate.lastName].filter((value) => typeof value === "string" && value).join(" "),
        completedExtraCount: Number(candidate.completedExtraCount),
        regularCount: Number(candidate.regularCount),
        lastCompletedExtraAt: candidate.lastCompletedExtraAt === null ? null : String(candidate.lastCompletedExtraAt),
        recommended: index === 0,
      };
    }),
  };
}

type ExtraAction = "add_extra_substitute" | "remove_extra_substitute";

export async function mutateExtraSubstitute(
  adminSupabase: SupabaseClient,
  action: ExtraAction,
  input: {
    actorUserId: string;
    teamId: string;
    seasonId: string;
    matchId: string;
    playerId: string;
    fingerprint: string;
  },
): Promise<"ok" | "stale" | "invalid"> {
  const { error } = await adminSupabase.rpc(action, {
    actor_user_id: input.actorUserId,
    target_team_id: input.teamId,
    target_season_id: input.seasonId,
    target_match_id: input.matchId,
    target_player_id: input.playerId,
    expected_fingerprint: input.fingerprint,
  });
  if (!error) return "ok";
  if (error.message.includes("STALE_SELECTION")) return "stale";
  if (error.message.includes("INVALID_EXTRA_SELECTION") || error.message.includes("MATCH_NOT_AVAILABLE")) return "invalid";
  throw new Error("Det gick inte att spara den extra inhopparen.");
}
