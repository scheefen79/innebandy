import type { SupabaseClient } from "@supabase/supabase-js";
import type { PlayerLevel } from "@/domain/player-level";

export type RosterPlayer = {
  id: string;
  name: string;
  level: PlayerLevel;
  isActive: boolean;
  selected: boolean;
  selectionSource: "automatic" | "manual" | null;
  selectionStatus: "selected" | "removed" | null;
  selectionType: "regular" | "extra" | null;
  replacedPlayerId: string | null;
};

export async function loadMatchRoster(
  supabase: SupabaseClient,
  teamId: string,
  seasonId: string,
  matchId: string,
): Promise<RosterPlayer[]> {
  const [{ data: players, error: playersError }, { data: selections, error: selectionsError }] = await Promise.all([
    supabase.from("players").select("id, first_name, last_name, level, rotation_order, is_active")
      .eq("team_id", teamId).eq("season_id", seasonId).order("rotation_order"),
    supabase.from("match_players").select("player_id, selection_type, selection_source, selection_status, replaced_player_id")
      .eq("team_id", teamId).eq("season_id", seasonId).eq("match_id", matchId),
  ]);
  if (playersError || selectionsError) throw new Error("Det gick inte att hämta laguttagningen.");
  const selectionsByPlayer = new Map((selections ?? []).map((item) => [item.player_id, item]));
  return (players ?? []).map((player) => ({
    id: player.id,
    name: [player.first_name, player.last_name].filter(Boolean).join(" "),
    level: player.level as PlayerLevel,
    isActive: player.is_active,
    selected: selectionsByPlayer.get(player.id)?.selection_status === "selected",
    selectionSource: selectionsByPlayer.get(player.id)?.selection_source ?? null,
    selectionStatus: selectionsByPlayer.get(player.id)?.selection_status ?? null,
    selectionType: selectionsByPlayer.get(player.id)?.selection_type ?? null,
    replacedPlayerId: selectionsByPlayer.get(player.id)?.replaced_player_id ?? null,
  }));
}
