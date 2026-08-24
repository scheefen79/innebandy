import type { SupabaseClient } from "@supabase/supabase-js";

export type OverviewMatch = { id:string; opponent:string; startsAt:string; location:string|null; targetPlayers:number; selectedPlayers:number };
export type OverviewPlayer = { id:string; name:string; regularCount:number };
export type FairnessGroup = { regularCount:number; playerCount:number; label:string };
export type OverviewData = { seasonName:string; serverNow:string; upcomingMatches:OverviewMatch[]; players:OverviewPlayer[] };

export function groupRegularCounts(players:OverviewPlayer[]):FairnessGroup[]{
 const counts=new Map<number,number>();for(const player of players)counts.set(player.regularCount,(counts.get(player.regularCount)??0)+1);
 return [...counts.entries()].sort(([left],[right])=>left-right).map(([regularCount,playerCount])=>({regularCount,playerCount,label:`${regularCount} ${regularCount===1?"ordinarie match":"ordinarie matcher"} – ${playerCount} ${playerCount===1?"spelare":"spelare"}`}));
}

export function hasFairnessWarning(players:OverviewPlayer[]){if(players.length<2)return false;const values=players.map(player=>player.regularCount);return Math.max(...values)-Math.min(...values)>1;}

export async function loadOverview(supabase:SupabaseClient,teamId:string):Promise<OverviewData>{
 const {data,error}=await supabase.rpc("get_overview",{target_team_id:teamId});if(error)throw new Error("Det gick inte att hämta översikten.");
 const envelope=data as Partial<OverviewData>|null;if(!envelope||typeof envelope.seasonName!=="string"||typeof envelope.serverNow!=="string"||!Array.isArray(envelope.upcomingMatches)||!Array.isArray(envelope.players))throw new Error("Översiktsunderlaget är ogiltigt.");
 const matches=envelope.upcomingMatches as OverviewMatch[];const players=envelope.players as OverviewPlayer[];
 if(matches.some(match=>typeof match.id!=="string"||typeof match.opponent!=="string"||typeof match.startsAt!=="string"||typeof match.targetPlayers!=="number"||typeof match.selectedPlayers!=="number")||players.some(player=>typeof player.id!=="string"||typeof player.name!=="string"||typeof player.regularCount!=="number"))throw new Error("Översiktsunderlaget är ogiltigt.");
 return {seasonName:envelope.seasonName,serverNow:envelope.serverNow,upcomingMatches:matches,players};
}
