import type { SupabaseClient } from "@supabase/supabase-js";
import type { PlayerLevel } from "@/domain/player-level";

export type RosterPlayer = {
  id: string;
  name: string;
  level: PlayerLevel | null;
  isActive: boolean;
  selected: boolean;
  selectionSource: "automatic" | "manual" | null;
  selectionStatus: "selected" | "removed" | null;
  selectionType: "regular" | "extra" | null;
  replacedPlayerId: string | null;
  played: boolean | null;
};

export async function loadMatchRoster(
  supabase: SupabaseClient,
  teamId: string,
  seasonId: string,
  matchId: string,
): Promise<RosterPlayer[]> {
  const {data,error}=await supabase.rpc("get_match_roster",{target_team_id:teamId,target_season_id:seasonId,target_match_id:matchId});
  if(error||!Array.isArray(data))throw new Error("Det gick inte att hämta laguttagningen.");
  return (data as Array<Record<string,unknown>>).map((player)=>{
    if(typeof player.id!=="string"||typeof player.name!=="string")throw new Error("Laguttagningen är ogiltig.");
    if(player.rosterGroup==="team"||player.rosterGroup==="resting"||player.rosterGroup==="extra")return {
      id:player.id,name:player.name,level:null,isActive:true,selected:player.rosterGroup!=="resting",
      selectionSource:null,selectionStatus:player.rosterGroup==="resting"?null:"selected",
      selectionType:player.rosterGroup==="extra"?"extra":player.rosterGroup==="team"?"regular":null,
      replacedPlayerId:null,played:null,
    } satisfies RosterPlayer;
    return player as RosterPlayer;
  });
}
