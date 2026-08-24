import type { SupabaseClient } from "@supabase/supabase-js";

export type PlayerProfileMatch = { id: string; opponent: string; startsAt: string; location: string | null; status: "upcoming" | "completed"; selectionType: "regular" | "extra"; selectionSource: "automatic" | "manual"; selectionStatus: "selected" | "removed"; played: boolean; isFuture: boolean };
export type PlayerProfile = { id: string; firstName: string; lastName: string | null; name: string; level: 1 | 2 | 3; isActive: boolean; fingerprint: string; matches: PlayerProfileMatch[] };

export async function loadPlayerProfile(supabase: SupabaseClient, teamId: string, seasonId: string, playerId: string): Promise<PlayerProfile | null> {
  const { data, error } = await supabase.rpc("get_player_profile", { target_team_id: teamId, target_season_id: seasonId, target_player_id: playerId });
  if (error) { if (error.message.includes("PLAYER_NOT_AVAILABLE")) return null; throw new Error("Det gick inte att hämta spelaren."); }
  const envelope = data as { player?: Record<string, unknown>; matches?: unknown; fingerprint?: unknown; serverNow?: unknown } | null;
  if (!envelope?.player || !Array.isArray(envelope.matches) || typeof envelope.fingerprint !== "string" || typeof envelope.serverNow !== "string") throw new Error("Spelarunderlaget är ogiltigt.");
  const player = envelope.player;
  if (typeof player.id !== "string" || typeof player.firstName !== "string" || (player.level !== 1 && player.level !== 2 && player.level !== 3) || typeof player.isActive !== "boolean") throw new Error("Spelarunderlaget är ogiltigt.");
  const serverNow = new Date(envelope.serverNow).getTime();
  if (!Number.isFinite(serverNow)) throw new Error("Spelarunderlaget är ogiltigt.");
  const matches = envelope.matches.map((raw) => raw as Omit<PlayerProfileMatch,"isFuture">).filter((match) => match.status === "upcoming" || match.status === "completed").map((match) => ({...match,isFuture:new Date(match.startsAt).getTime()>serverNow}));
  const lastName = typeof player.lastName === "string" ? player.lastName : null;
  return { id: player.id, firstName: player.firstName, lastName, name: [player.firstName, lastName].filter(Boolean).join(" "), level: player.level, isActive: player.isActive, fingerprint: envelope.fingerprint, matches };
}

export function summarizePlayerMatches(matches: PlayerProfileMatch[]) {
  const count = (status: "upcoming" | "completed", type: "regular" | "extra", played?: boolean) => matches.filter((match) => match.selectionStatus === "selected" && match.status === status && match.selectionType === type && (played === undefined || match.played === played)).length;
  return { plannedRegular: count("upcoming", "regular"), completedRegular: count("completed", "regular", true), plannedExtra: count("upcoming", "extra"), completedExtra: count("completed", "extra", true) };
}
