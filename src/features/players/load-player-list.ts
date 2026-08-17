import type { SupabaseClient } from "@supabase/supabase-js";

import { toPlayerListItems, type PlayerListItem, type PlayerRow } from "./player-list";

type PlayerListData = {
  players: PlayerListItem[];
  seasonName: string;
};

export async function loadPlayerList(
  supabase: SupabaseClient,
  teamId: string,
): Promise<PlayerListData> {
  const { data: season, error: seasonError } = await supabase
    .from("seasons")
    .select("id, name")
    .eq("team_id", teamId)
    .eq("is_active", true)
    .maybeSingle();

  if (seasonError) {
    throw new Error("Det gick inte att hämta den aktiva säsongen.");
  }

  if (!season) {
    throw new Error("Laget saknar en aktiv säsong.");
  }

  const { data: playerRows, error: playersError } = await supabase
    .from("players")
    .select("id, first_name, last_name, level, rotation_order")
    .eq("team_id", teamId)
    .eq("season_id", season.id)
    .eq("is_active", true)
    .order("rotation_order");

  if (playersError) {
    throw new Error("Det gick inte att hämta spelarna.");
  }

  return {
    players: toPlayerListItems((playerRows ?? []) as PlayerRow[]),
    seasonName: season.name,
  };
}
