import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadTeamMemberList } from "@/features/team-members/load-team-member-list";
import { TeamMemberListView } from "@/features/team-members/team-member-list-view";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function TeamMembersPage({ searchParams }: { searchParams: Promise<{ inviteError?: string; mutationError?: string }> }) {
  const supabase = await createClient();
  const userId = await getVerifiedUserId();
  if (!userId) redirect("/login?next=/team");
  const context = await loadTeamContext(supabase);
  if (!context || context.role !== "coach") redirect("/access-denied");
  const members = await loadTeamMemberList(supabase, context.teamId);
  const { inviteError, mutationError } = await searchParams;

  return (
    <AppShell currentItem="Medlemmar" role={context.role}>
      <TeamMemberListView members={members} inviteError={inviteError ?? null} mutationError={mutationError ?? null} />
    </AppShell>
  );
}
