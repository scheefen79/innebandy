import type { SupabaseClient } from "@supabase/supabase-js";

export type CompletionParticipant = {
  playerId: string;
  name: string;
  selectionType: "regular" | "extra";
  played: boolean;
};

export function defaultPlayedPlayerIds(participants: CompletionParticipant[]) {
  return participants.map((participant) => participant.playerId);
}

export function summarizeParticipation(participants: CompletionParticipant[], playedPlayerIds: Iterable<string>) {
  const played = new Set(playedPlayerIds);
  const count = (selectionType: "regular" | "extra", didPlay: boolean) => participants.filter((participant) => participant.selectionType === selectionType && played.has(participant.playerId) === didPlay).length;
  return { regularPlayed: count("regular", true), regularAbsent: count("regular", false), extraPlayed: count("extra", true), extraAbsent: count("extra", false) };
}

export async function loadMatchCompletionSource(
  supabase: SupabaseClient,
  teamId: string,
  seasonId: string,
  matchId: string,
): Promise<{ fingerprint: string; participants: CompletionParticipant[] }> {
  const { data, error } = await supabase.rpc("get_match_completion_source", {
    target_team_id: teamId,
    target_season_id: seasonId,
    target_match_id: matchId,
  });
  if (error) throw new Error("Det gick inte att hämta deltagandet.");
  const envelope = data as { fingerprint?: unknown; participants?: unknown } | null;
  if (!envelope || typeof envelope.fingerprint !== "string" || !Array.isArray(envelope.participants)) {
    throw new Error("Deltagandeunderlaget är ogiltigt.");
  }
  const participants = envelope.participants.map((raw) => {
    const item = raw as Record<string, unknown>;
    if (typeof item.playerId !== "string" || (item.selectionType !== "regular" && item.selectionType !== "extra") || typeof item.played !== "boolean") {
      throw new Error("Deltagandeunderlaget är ogiltigt.");
    }
    return {
      playerId: item.playerId,
      name: [item.firstName, item.lastName].filter((value) => typeof value === "string" && value).join(" "),
      selectionType: item.selectionType as "regular" | "extra",
      played: item.played,
    };
  });
  return { fingerprint: envelope.fingerprint, participants };
}

export function buildParticipation(playerIds: string[], playedPlayerIds: string[]) {
  if (new Set(playerIds).size !== playerIds.length) return null;
  const allowed = new Set(playerIds);
  const played = new Set(playedPlayerIds);
  if (played.size !== playedPlayerIds.length || playedPlayerIds.some((id) => !allowed.has(id))) return null;
  return playerIds.map((playerId) => ({ playerId, played: played.has(playerId) }));
}

export async function completeMatch(
  adminSupabase: SupabaseClient,
  input: {
    actorUserId: string;
    teamId: string;
    seasonId: string;
    matchId: string;
    fingerprint: string;
    participation: { playerId: string; played: boolean }[];
  },
): Promise<"ok" | "stale" | "completed" | "invalid"> {
  const { error } = await adminSupabase.rpc("complete_match", {
    actor_user_id: input.actorUserId,
    target_team_id: input.teamId,
    target_season_id: input.seasonId,
    target_match_id: input.matchId,
    expected_fingerprint: input.fingerprint,
    participation: input.participation,
  });
  if (!error) return "ok";
  if (error.message.includes("STALE_SELECTION")) return "stale";
  if (error.message.includes("MATCH_ALREADY_COMPLETED")) return "completed";
  if (error.message.includes("INVALID_PARTICIPATION") || error.message.includes("MATCH_NOT_AVAILABLE")) return "invalid";
  throw new Error("Det gick inte att genomföra matchen.");
}
