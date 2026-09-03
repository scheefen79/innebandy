import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadMatch } from "@/features/matches/load-matches";
import { loadExtraSubstituteSource } from "@/features/selections/extra-substitute";
import { loadMatchRoster } from "@/features/selections/load-match-roster";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createClient } from "@/lib/supabase/server";
import { ExtraForm } from "./extra-form";

export const dynamic = "force-dynamic";

export default async function ExtraSubstitutePage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const userId = await getVerifiedUserId();
  if (!userId) redirect(`/login?next=${encodeURIComponent(`/matches/${id}/extras`)}`);
  const context = await loadTeamContext(supabase);
  if (!context || context.role !== "coach") redirect("/access-denied");
  const match = await loadMatch(supabase, context.teamId, context.seasonId, id);
  if (!match) notFound();
  if (match.status !== "upcoming" || Date.parse(match.startsAt) <= Date.parse(new Date().toISOString())) redirect(`/matches/${id}`);
  const roster = await loadMatchRoster(supabase, context.teamId, context.seasonId, id);
  const regularCount = roster.filter((player) => player.selectionType === "regular" && player.selectionStatus === "selected").length;
  if (regularCount !== match.targetPlayers) redirect(`/matches/${id}`);
  const source = await loadExtraSubstituteSource(supabase, context.teamId, context.seasonId, id);
  const error = (await searchParams).error;
  return <AppShell currentItem="Matcher" role={context.role}><main className="mx-auto max-w-2xl">
    <Link href={`/matches/${id}`} className="inline-flex min-h-11 items-center text-sm font-semibold text-blue-700">← Till matchen</Link>
    <h1 className="mt-2 text-3xl font-bold text-slate-950">Lägg till extra inhoppare</h1>
    <p className="mt-2 text-slate-600">{match.opponent}. Extra inhopp påverkar inte den ordinarie fördelningen.</p>
    {error ? <div role="alert" className="mt-5 rounded-xl border border-amber-300 bg-amber-50 p-4 text-sm text-amber-950">{error === "stale" ? "Uttagningen ändrades innan valet sparades. Kontrollera kandidaterna och försök igen." : "Spelaren är inte längre tillgänglig för matchen."}</div> : null}
    {source.candidates.length === 0 ? <section className="mt-6 rounded-xl bg-white p-5 shadow-sm"><h2 className="font-semibold text-slate-950">Inga tillgängliga spelare</h2><p className="mt-2 text-sm text-slate-600">Alla aktiva spelare har redan en plats eller ett beslut i matchen.</p></section> : <div className="mt-6"><ExtraForm action={`/matches/${id}/extras/add`} candidates={source.candidates} fingerprint={source.fingerprint} /></div>}
  </main></AppShell>;
}
