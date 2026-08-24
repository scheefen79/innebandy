import type { SupabaseClient } from "@supabase/supabase-js";

import { getPlayerLevelLabel, type PlayerLevel } from "@/domain/player-level";
import type { PlayerListItem } from "./player-list";

type PlayerListData = {
  players: PlayerListItem[];
  seasonName: string;
};

export async function loadPlayerList(
  supabase: SupabaseClient,
  teamId: string,
): Promise<PlayerListData> {
  const { data, error } = await supabase.rpc("get_player_list", { target_team_id: teamId });
  if (error) throw new Error(error.message.includes("ACTIVE_SEASON_NOT_AVAILABLE") ? "Laget saknar en aktiv säsong." : "Det gick inte att hämta spelarna.");
  const envelope = data as { seasonName?: unknown; players?: unknown } | null;
  if (!envelope || typeof envelope.seasonName !== "string" || !Array.isArray(envelope.players)) throw new Error("Spelarlistan är ogiltig.");
  const players = envelope.players.map((raw) => {
    const player = raw as Record<string, unknown>;
    if (typeof player.id !== "string" || typeof player.firstName !== "string" || (player.level !== 1 && player.level !== 2 && player.level !== 3)) throw new Error("Spelarlistan är ogiltig.");
    const level = player.level as PlayerLevel;
    const lastName = typeof player.lastName === "string" ? player.lastName : null;
    const number = (value: unknown) => typeof value === "number" ? value : 0;
    return { id: player.id, name: [player.firstName, lastName].filter(Boolean).join(" "), level, levelLabel: getPlayerLevelLabel(level), plannedRegular: number(player.plannedRegular), completedRegular: number(player.completedRegular), plannedExtra: number(player.plannedExtra), completedExtra: number(player.completedExtra) };
  });

  return {
    players,
    seasonName: envelope.seasonName,
  };
}
