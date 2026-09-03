import type { SupabaseClient } from "@supabase/supabase-js";
import type { TeamMemberListItem } from "./team-member-list";

export async function loadTeamMemberList(supabase: SupabaseClient, teamId: string): Promise<TeamMemberListItem[]> {
  const { data, error } = await supabase.rpc("get_team_member_list", { target_team_id: teamId });
  if (error) throw new Error("Det gick inte att hämta medlemmarna.");
  if (!Array.isArray(data)) throw new Error("Medlemslistan är ogiltig.");
  return data.map((raw) => {
    const member = raw as Record<string, unknown>;
    if (
      typeof member.userId !== "string" ||
      typeof member.email !== "string" ||
      (member.role !== "coach" && member.role !== "viewer") ||
      typeof member.isActive !== "boolean" ||
      typeof member.invitedAt !== "string" ||
      typeof member.fingerprint !== "string"
    ) {
      throw new Error("Medlemslistan är ogiltig.");
    }
    return {
      userId: member.userId,
      email: member.email,
      role: member.role,
      isActive: member.isActive,
      invitedAt: member.invitedAt,
      fingerprint: member.fingerprint,
    };
  });
}
