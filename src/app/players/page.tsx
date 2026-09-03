import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadPlayerList } from "@/features/players/load-player-list";
import { PlayerListView } from "@/features/players/player-list-view";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createClient } from "@/lib/supabase/server";

export const dynamic="force-dynamic";
export default async function PlayersPage(){const supabase=await createClient();const userId=await getVerifiedUserId();if(!userId)redirect("/login?next=/players");const context=await loadTeamContext(supabase);if(!context||context.role!=="coach")redirect("/access-denied");const {players,seasonName}=await loadPlayerList(supabase,context.teamId);return <AppShell currentItem="Spelare" role={context.role}><PlayerListView players={players} seasonName={seasonName}/></AppShell>;}
