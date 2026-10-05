import { redirect } from "next/navigation";
import { isUuid } from "@/features/matches/match-validation";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createClient } from "@/lib/supabase/server";
export const dynamic = "force-dynamic";
export default async function LegacyMatchPage({ params }: { params: Promise<{ id: string }> }) {
  if (!await getVerifiedUserId()) redirect("/login?next=/matches");
  const context = await loadTeamContext(await createClient());
  if (!context || context.role !== "coach") redirect("/access-denied");
  const { id } = await params;
  redirect(isUuid(id) ? `/matches/${id}/week` : "/matches");
}
