import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { OpponentLabel } from "@/components/team-logo";
import { loadMatch } from "@/features/matches/load-matches";
import { formatStockholmDateTime } from "@/features/matches/match-time";
import { loadMatchRoster } from "@/features/selections/load-match-roster";
import { loadExtraSubstituteSource, shouldLoadExtraSubstituteSource } from "@/features/selections/extra-substitute";
import { loadManualAdjustmentFingerprint } from "@/features/selections/manual-adjustment";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function MatchPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ tab?: string; adjustment?: string; extra?: string; completion?: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const userId = await getVerifiedUserId();
  if (!userId) redirect(`/login?next=${encodeURIComponent(`/matches/${id}`)}`);
  const context = await loadTeamContext(supabase);
  if (!context) redirect("/access-denied");
  const match = await loadMatch(supabase, context.teamId, context.seasonId, id);
  if (!match) notFound();
  const roster = await loadMatchRoster(supabase, context.teamId, context.seasonId, id);
  const query = await searchParams;
  const tab = query.tab === "resting" ? "resting" : "team";
  const visiblePlayers = roster.filter((player) => tab === "team" ? player.selected && player.selectionType === "regular" : !player.selected && (player.isActive || player.selectionStatus === "removed"));
  const canAdjust = match.status === "upcoming" && Date.parse(match.startsAt) > Date.parse(new Date().toISOString());
  const hasSavedRegularRoster = roster.filter((player) => player.selectionType === "regular" && player.selectionStatus === "selected").length === match.targetPlayers;
  const canComplete = match.status === "upcoming" && Date.parse(match.startsAt) <= Date.parse(new Date().toISOString()) && hasSavedRegularRoster;
  const extraPlayers = roster.filter((player) => player.selectionType === "extra" && player.selectionStatus === "selected");
  const fingerprint = canAdjust ? await loadManualAdjustmentFingerprint(supabase, context.teamId, context.seasonId, id) : null;
  const extraSource = shouldLoadExtraSubstituteSource({ canAdjust, hasSavedRegularRoster, extraPlayerCount: extraPlayers.length })
    ? await loadExtraSubstituteSource(supabase, context.teamId, context.seasonId, id)
    : null;
  const automaticPlayers = roster.filter((player) => player.selectionType === "regular" && player.selectionSource === "automatic" && player.selectionStatus === "selected");
  const availablePlayers = roster.filter((player) => player.isActive && player.selectionStatus === null);

  const status = match.status === "upcoming" ? "Planerad" : match.status === "completed" ? "Genomförd" : "Inställd";
  return <AppShell currentItem="Matcher"><article className="mx-auto max-w-2xl">
    <Link href="/matches" className="inline-flex min-h-11 items-center text-sm font-semibold text-blue-700">← Till matcher</Link>
    <div className="mt-2 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
      {query.adjustment === "saved" ? <p role="status" className="mb-4 rounded-xl bg-emerald-50 p-3 text-sm font-medium text-emerald-900">Det manuella bytet är sparat.</p> : null}
      {query.adjustment === "restored" ? <p role="status" className="mb-4 rounded-xl bg-emerald-50 p-3 text-sm font-medium text-emerald-900">Det manuella bytet är återställt.</p> : null}
      {query.adjustment === "stale" || query.adjustment === "invalid" ? <p role="alert" className="mb-4 rounded-xl bg-amber-50 p-3 text-sm font-medium text-amber-950">Laget ändrades innan åtgärden sparades. Kontrollera det aktuella laget och försök igen.</p> : null}
      {query.extra === "added" ? <p role="status" className="mb-4 rounded-xl bg-emerald-50 p-3 text-sm font-medium text-emerald-900">Den extra inhopparen är tillagd.</p> : null}
      {query.extra === "removed" ? <p role="status" className="mb-4 rounded-xl bg-emerald-50 p-3 text-sm font-medium text-emerald-900">Den extra inhopparen är borttagen.</p> : null}
      {query.extra === "stale" || query.extra === "invalid" ? <p role="alert" className="mb-4 rounded-xl bg-amber-50 p-3 text-sm font-medium text-amber-950">Extra uttagningen ändrades innan åtgärden sparades. Kontrollera matchen och försök igen.</p> : null}
      {query.completion === "saved" ? <p role="status" className="mb-4 rounded-xl bg-emerald-50 p-3 text-sm font-medium text-emerald-900">Matchen är genomförd och deltagandet är sparat.</p> : null}
      {query.completion === "conflict" ? <p role="alert" className="mb-4 rounded-xl bg-amber-50 p-3 text-sm font-medium text-amber-950">En annan tränare hann genomföra matchen med ett annat deltagande. Det sparade deltagandet visas nedan och ditt förslag skrev inte över det.</p> : null}
      <span className="rounded-full bg-blue-50 px-3 py-1 text-xs font-semibold text-blue-800">{status}</span>
      <h1 className="mt-4 break-words text-3xl font-bold text-slate-950"><OpponentLabel opponent={match.opponent} size="lg" /></h1>
      <dl className="mt-7 grid gap-5 sm:grid-cols-2"><div><dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Datum och tid</dt><dd className="mt-1 text-slate-900">{formatStockholmDateTime(match.startsAt)}</dd></div><div><dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Plats</dt><dd className="mt-1 break-words text-slate-900">{match.location ?? "Ej angiven"}</dd></div><div><dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Matchplatser</dt><dd className="mt-1 text-slate-900">{match.targetPlayers}</dd></div><div><dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Säsong</dt><dd className="mt-1 text-slate-900">{context.seasonName}</dd></div></dl>
      <section className="mt-7"><nav aria-label="Laguttagning" className="flex border-b border-slate-200"><Link href={`/matches/${id}`} aria-current={tab === "team" ? "page" : undefined} className={`min-h-11 px-4 py-3 text-sm font-semibold ${tab === "team" ? "border-b-2 border-blue-700 text-blue-700" : "text-slate-600"}`}>Lag ({roster.filter((player) => player.selected && player.selectionType === "regular").length})</Link><Link href={`/matches/${id}?tab=resting`} aria-current={tab === "resting" ? "page" : undefined} className={`min-h-11 px-4 py-3 text-sm font-semibold ${tab === "resting" ? "border-b-2 border-blue-700 text-blue-700" : "text-slate-600"}`}>Står över ({roster.filter((player) => !player.selected && player.isActive).length})</Link></nav>{visiblePlayers.length === 0 ? <div className="rounded-b-xl bg-slate-50 p-4"><h2 className="font-semibold text-slate-900">{tab === "team" ? "Ingen laguttagning ännu" : "Ingen står över"}</h2><p className="mt-1 text-sm text-slate-600">{tab === "team" ? "Generera fördelningen från matchlistan." : "Alla aktiva spelare är uttagna."}</p></div> : <ul className="divide-y divide-slate-200">{visiblePlayers.map((player) => <li key={player.id} className="py-3"><div className="flex min-w-0 items-center justify-between gap-3"><span className="min-w-0"><span className="block truncate font-medium text-slate-900">{player.name}</span>{match.status === "completed" && player.selectionStatus === "selected" ? <span className={`mt-1 inline-block rounded-full px-2 py-0.5 text-xs font-medium ${player.played ? "bg-emerald-50 text-emerald-800" : "bg-amber-50 text-amber-900"}`}>{player.played ? "Spelade" : "Deltog inte"}</span> : player.selectionSource === "manual" ? <span className={`mt-1 inline-block rounded-full px-2 py-0.5 text-xs font-medium ${player.selectionStatus === "selected" ? "bg-blue-50 text-blue-800" : "bg-amber-50 text-amber-900"}`}>{player.selectionStatus === "selected" ? "Manuellt tillagd" : "Manuellt borttagen"}</span> : null}</span><span className="shrink-0 rounded-full bg-slate-100 px-2 py-1 text-xs text-slate-600">Nivå {player.level}</span></div>{player.selectionSource === "manual" && player.selectionStatus === "selected" && player.replacedPlayerId && fingerprint ? <details className="mt-3 rounded-lg bg-slate-50 p-3"><summary className="cursor-pointer text-sm font-semibold text-blue-700">Återställ manuellt byte</summary><p className="mt-2 text-sm text-slate-600">Den tidigare automatiska spelaren återgår till laget.</p><form action={`/matches/${id}/adjust/restore`} method="post" className="mt-3"><input type="hidden" name="outgoingPlayerId" value={player.replacedPlayerId} /><input type="hidden" name="incomingPlayerId" value={player.id} /><input type="hidden" name="fingerprint" value={fingerprint} /><button className="min-h-11 rounded-lg border border-red-300 px-3 text-sm font-semibold text-red-800">Ja, återställ bytet</button></form></details> : null}</li>)}</ul>}</section>
      <section className="mt-7 rounded-xl bg-slate-50 p-4"><h2 className="text-lg font-semibold text-slate-950">Extra inhoppare</h2>{extraPlayers.length === 0 ? <p className="mt-2 text-sm text-slate-600">Ingen extra inhoppare är tillagd.</p> : <ul className="mt-3 divide-y divide-slate-200">{extraPlayers.map((player) => <li key={player.id} className="py-3"><div className="flex min-w-0 items-center justify-between gap-3"><span className="min-w-0 truncate font-medium text-slate-900">{player.name}</span><span className={`shrink-0 rounded-full px-2 py-1 text-xs font-semibold ${match.status === "completed" && !player.played ? "bg-amber-50 text-amber-900" : "bg-violet-100 text-violet-800"}`}>{match.status === "completed" ? `Extra inhoppare · ${player.played ? "Spelade" : "Deltog inte"}` : "Extra inhoppare"}</span></div>{canAdjust && extraSource ? <details className="mt-3"><summary className="cursor-pointer text-sm font-semibold text-red-700">Ta bort extra inhoppare</summary><form action={`/matches/${id}/extras/remove`} method="post" className="mt-3"><input type="hidden" name="playerId" value={player.id} /><input type="hidden" name="fingerprint" value={extraSource.fingerprint} /><button className="min-h-11 rounded-lg border border-red-300 px-3 text-sm font-semibold text-red-800">Ja, ta bort</button></form></details> : null}</li>)}</ul>}</section>
      {canAdjust && automaticPlayers.length > 0 && availablePlayers.length > 0 ? <Link href={`/matches/${id}/adjust`} className="mt-6 inline-flex min-h-12 w-full items-center justify-center rounded-xl bg-blue-700 px-4 font-semibold text-white">Justera ordinarie lag</Link> : null}
      {canAdjust && hasSavedRegularRoster && extraSource && extraSource.candidates.length > 0 ? <Link href={`/matches/${id}/extras`} className="mt-3 inline-flex min-h-12 w-full items-center justify-center rounded-xl border border-blue-700 px-4 font-semibold text-blue-700">Lägg till extra inhoppare</Link> : null}
      {canComplete ? <Link href={`/matches/${id}/complete`} className="mt-3 inline-flex min-h-12 w-full items-center justify-center rounded-xl bg-blue-700 px-4 font-semibold text-white">Genomför match</Link> : null}
    </div>
  </article></AppShell>;
}
