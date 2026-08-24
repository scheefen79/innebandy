import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadPlayerList } from "@/features/players/load-player-list";
import { PlayerListView } from "@/features/players/player-list-view";
import { loadTeamContext } from "@/lib/auth/team-context";
import { createClient } from "@/lib/supabase/server";

export const dynamic="force-dynamic";
export default async function PlayersPage(){const supabase=await createClient();const {data}=await supabase.auth.getClaims();if(!data?.claims?.sub)redirect("/login?next=/players");const context=await loadTeamContext(supabase);if(!context)redirect("/access-denied");const {players,seasonName}=await loadPlayerList(supabase,context.teamId);return <AppShell currentItem="Spelare"><PlayerListView players={players} seasonName={seasonName}/></AppShell>;}
