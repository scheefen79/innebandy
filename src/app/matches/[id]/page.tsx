import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadMatch } from "@/features/matches/load-matches";
import { formatStockholmDateTime } from "@/features/matches/match-time";
import { loadMatchRoster } from "@/features/selections/load-match-roster";
import { loadTeamContext } from "@/lib/auth/team-context";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function MatchPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ tab?: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  if (!data?.claims?.sub) redirect(`/login?next=${encodeURIComponent(`/matches/${id}`)}`);
  const context = await loadTeamContext(supabase);
  if (!context) redirect("/access-denied");
  const match = await loadMatch(supabase, context.teamId, context.seasonId, id);
  if (!match) notFound();
  const roster = await loadMatchRoster(supabase, context.teamId, context.seasonId, id);
  const tab = (await searchParams).tab === "resting" ? "resting" : "team";
  const visiblePlayers = roster.filter((player) => tab === "team" ? player.selected : !player.selected);

  const status = match.status === "upcoming" ? "Planerad" : match.status === "completed" ? "Genomförd" : "Inställd";
  return <AppShell currentItem="Matcher"><article className="mx-auto max-w-2xl">
    <Link href="/matches" className="inline-flex min-h-11 items-center text-sm font-semibold text-blue-700">← Till matcher</Link>
    <div className="mt-2 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
      <span className="rounded-full bg-blue-50 px-3 py-1 text-xs font-semibold text-blue-800">{status}</span>
      <h1 className="mt-4 break-words text-3xl font-bold text-slate-950">{match.opponent}</h1>
      <dl className="mt-7 grid gap-5 sm:grid-cols-2"><div><dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Datum och tid</dt><dd className="mt-1 text-slate-900">{formatStockholmDateTime(match.startsAt)}</dd></div><div><dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Plats</dt><dd className="mt-1 break-words text-slate-900">{match.location ?? "Ej angiven"}</dd></div><div><dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Matchplatser</dt><dd className="mt-1 text-slate-900">{match.targetPlayers}</dd></div><div><dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Säsong</dt><dd className="mt-1 text-slate-900">{context.seasonName}</dd></div></dl>
      <section className="mt-7"><nav aria-label="Laguttagning" className="flex border-b border-slate-200"><Link href={`/matches/${id}`} aria-current={tab === "team" ? "page" : undefined} className={`min-h-11 px-4 py-3 text-sm font-semibold ${tab === "team" ? "border-b-2 border-blue-700 text-blue-700" : "text-slate-600"}`}>Lag ({roster.filter((player) => player.selected).length})</Link><Link href={`/matches/${id}?tab=resting`} aria-current={tab === "resting" ? "page" : undefined} className={`min-h-11 px-4 py-3 text-sm font-semibold ${tab === "resting" ? "border-b-2 border-blue-700 text-blue-700" : "text-slate-600"}`}>Står över ({roster.filter((player) => !player.selected).length})</Link></nav>{visiblePlayers.length === 0 ? <div className="rounded-b-xl bg-slate-50 p-4"><h2 className="font-semibold text-slate-900">{tab === "team" ? "Ingen laguttagning ännu" : "Ingen står över"}</h2><p className="mt-1 text-sm text-slate-600">{tab === "team" ? "Generera fördelningen från matchlistan." : "Alla aktiva spelare är uttagna."}</p></div> : <ul className="divide-y divide-slate-200">{visiblePlayers.map((player) => <li key={player.id} className="flex min-w-0 items-center justify-between gap-3 py-3"><span className="truncate font-medium text-slate-900">{player.name}</span><span className="shrink-0 rounded-full bg-slate-100 px-2 py-1 text-xs text-slate-600">Nivå {player.level}</span></li>)}</ul>}</section>
    </div>
  </article></AppShell>;
}
