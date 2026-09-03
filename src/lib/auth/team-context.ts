import type { SupabaseClient } from "@supabase/supabase-js";

export type TeamRole = "coach" | "viewer";
export type TeamContext = { teamId: string; seasonId: string; seasonName: string; role: TeamRole };

export function isCoach(context: TeamContext): boolean {
  return context.role === "coach";
}

export async function loadTeamContext(supabase: SupabaseClient): Promise<TeamContext | null> {
  const {data,error}=await supabase.rpc("get_team_context");
  if(error){if(error.message.includes("TEAM_CONTEXT_NOT_AVAILABLE"))return null;throw new Error("Det gick inte att verifiera lagbehörigheten.");}
  const context=data as Partial<TeamContext>|null;
  if(!context||typeof context.teamId!=="string"||typeof context.seasonId!=="string"||typeof context.seasonName!=="string"||(context.role!=="coach"&&context.role!=="viewer"))throw new Error("Lagunderlaget är ogiltigt.");
  return {teamId:context.teamId,seasonId:context.seasonId,seasonName:context.seasonName,role:context.role};
}
