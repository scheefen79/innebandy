import type { SupabaseClient } from "@supabase/supabase-js";
import { isUuid } from "./match-validation";

export type MatchListItem = {
  id: string; opponent: string; startsAt: string; location: string | null;
  selectedPlayers: number; targetPlayers: number; status: "upcoming" | "completed" | "cancelled";
};

type MatchRow = {
  id:string; opponent:string; starts_at:string; location:string|null;
  target_players:number; status:MatchListItem["status"];
};

export async function loadMatches(
  supabase: SupabaseClient,
  teamId: string,
  seasonId: string,
  filter: "upcoming" | "all",
  now: string,
): Promise<MatchListItem[]> {
  const {data,error}=await supabase.rpc("get_match_list",{target_team_id:teamId,target_season_id:seasonId,requested_filter:filter,requested_now:now});
  if(error||!Array.isArray(data))throw new Error("Det gick inte att hämta matcherna.");
  return data as MatchListItem[];
}

export async function loadMatch(
  supabase: SupabaseClient,
  teamId: string,
  seasonId: string,
  matchId: string,
): Promise<MatchListItem | null> {
  if (!isUuid(matchId)) return null;
  const { data, error } = await supabase.from("matches")
    .select("id, opponent, starts_at, location, target_players, status")
    .eq("id", matchId).eq("team_id", teamId).eq("season_id", seasonId).maybeSingle();
  if (error) throw new Error("Det gick inte att hämta matchen.");
  if (!data) return null;
  const row = data as MatchRow;
  return { id: row.id, opponent: row.opponent, startsAt: row.starts_at, location: row.location, selectedPlayers: 0, targetPlayers: row.target_players, status: row.status };
}
