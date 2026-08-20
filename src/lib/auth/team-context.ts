import type { SupabaseClient } from "@supabase/supabase-js";

export type TeamContext = { teamId: string; seasonId: string; seasonName: string };

export async function loadTeamContext(supabase: SupabaseClient): Promise<TeamContext | null> {
  const { data: membership, error: membershipError } = await supabase.from("team_members")
    .select("team_id").eq("is_active", true).limit(1).maybeSingle();
  if (membershipError) throw new Error("Det gick inte att verifiera lagbehörigheten.");
  if (!membership) return null;

  const { data: season, error: seasonError } = await supabase.from("seasons")
    .select("id, name").eq("team_id", membership.team_id).eq("is_active", true).maybeSingle();
  if (seasonError) throw new Error("Det gick inte att hämta den aktiva säsongen.");
  if (!season) throw new Error("Laget saknar en aktiv säsong.");
  return { teamId: membership.team_id, seasonId: season.id, seasonName: season.name };
}
