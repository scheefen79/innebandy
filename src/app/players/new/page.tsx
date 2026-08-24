import Link from "next/link";
import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadTeamContext } from "@/lib/auth/team-context";
import { createClient } from "@/lib/supabase/server";
import { PlayerForm } from "../player-form";

export const dynamic = "force-dynamic";
export default async function NewPlayerPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const supabase=await createClient(); const {data}=await supabase.auth.getClaims(); if(!data?.claims?.sub) redirect("/login?next=/players/new");
  const context=await loadTeamContext(supabase); if(!context) redirect("/access-denied"); const error=(await searchParams).error;
  return <AppShell currentItem="Spelare"><main className="mx-auto max-w-xl"><Link href="/players" className="inline-flex min-h-11 items-center text-sm font-semibold text-blue-700">← Till spelare</Link><h1 className="mt-2 text-3xl font-bold text-slate-950">Lägg till spelare</h1><p className="mt-2 text-slate-600">Spelaren läggs till i {context.seasonName}. Befintliga uttagningar ändras inte.</p>{error ? <p role="alert" className="mt-5 rounded-xl bg-amber-50 p-4 text-sm text-amber-950">{error}</p>:null}<div className="mt-6"><PlayerForm action="/players/create" submitLabel="Lägg till spelare" requestId={crypto.randomUUID()} /></div></main></AppShell>;
}
