import { AppShell } from "@/components/app-shell";
import { loadPlayerList } from "@/features/players/load-player-list";
import { PlayerListView } from "@/features/players/player-list-view";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export const dynamic = "force-dynamic";

export default async function Home() {
  const supabase = await createClient();
  const { data: verifiedSession } = await supabase.auth.getClaims();
  const claims = verifiedSession?.claims;

  if (!claims?.sub) {
    redirect("/login");
  }

  const { data: membership, error: membershipError } = await supabase
    .from("team_members")
    .select("team_id")
    .eq("is_active", true)
    .limit(1)
    .maybeSingle();

  if (membershipError) {
    throw new Error("Det gick inte att verifiera lagbehörigheten.");
  }

  if (!membership) {
    redirect("/access-denied");
  }

  const { players, seasonName } = await loadPlayerList(supabase, membership.team_id);

  return (
    <AppShell currentItem="Spelare">
      <PlayerListView players={players} seasonName={seasonName} />
    </AppShell>
  );
}
