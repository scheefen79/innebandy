import type { SupabaseClient } from "@supabase/supabase-js";
import { isUuid } from "./match-validation";

export type MatchListItem = {
  id: string; opponent: string; startsAt: string; location: string | null;
  selectedPlayers: number; targetPlayers: number; status: "upcoming" | "completed" | "cancelled";
};

type MatchRow = {
  id: string; opponent: string; starts_at: string; location: string | null;
  target_players: number; status: MatchListItem["status"];
};

export async function loadMatches(
  supabase: SupabaseClient,
  teamId: string,
  seasonId: string,
  filter: "upcoming" | "all",
  now: string,
): Promise<MatchListItem[]> {
  let query = supabase.from("matches")
    .select("id, opponent, starts_at, location, target_players, status")
    .eq("team_id", teamId).eq("season_id", seasonId);

  if (filter === "upcoming") query = query.eq("status", "upcoming").gte("starts_at", now);
  const { data, error } = await query.order("starts_at", { ascending: filter === "upcoming" });
  if (error) throw new Error("Det gick inte att hämta matcherna.");
  const rows = (data ?? []) as MatchRow[];
  const counts = new Map<string, number>();
  if (rows.length > 0) {
    const { data: selections, error: selectionsError } = await supabase.from("match_players")
      .select("match_id").in("match_id", rows.map((row) => row.id))
      .eq("selection_type", "regular").eq("selection_status", "selected");
    if (selectionsError) throw new Error("Det gick inte att räkna laguttagningarna.");
    for (const selection of selections ?? []) counts.set(selection.match_id, (counts.get(selection.match_id) ?? 0) + 1);
  }
  return rows.map((row) => ({
    id: row.id, opponent: row.opponent, startsAt: row.starts_at,
    location: row.location, selectedPlayers: counts.get(row.id) ?? 0,
    targetPlayers: row.target_players, status: row.status,
  }));
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
