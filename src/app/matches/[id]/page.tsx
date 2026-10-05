import Link from "next/link";
import { randomUUID } from "node:crypto";
import { CancelMatchForm } from "@/features/match-workflow/cancel-match-form";
import { notFound, redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { OpponentLabel } from "@/components/team-logo";
import { loadMatch } from "@/features/matches/load-matches";
import { formatStockholmDateTime } from "@/features/matches/match-time";
import { loadMatchRoster } from "@/features/selections/load-match-roster";
import { loadMatchWorkflow, summarizeResponses } from "@/features/match-workflow/workflow";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createClient } from "@/lib/supabase/server";
export const dynamic = "force-dynamic";
export default async function MatchPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ tab?: string }> }) {
  const { id } = await params;
  const now = new Date().toISOString();
  const supabase = await createClient();
  if (!await getVerifiedUserId()) redirect(`/login?next=${encodeURIComponent(`/matches/${id}`)}`);
  const context = await loadTeamContext(supabase);
  if (!context) redirect("/access-denied");
  const match = await loadMatch(supabase, context.teamId, context.seasonId, id);
  if (!match) notFound();
  const roster = await loadMatchRoster(supabase, context.teamId, context.seasonId, id);
  const workflow = context.role === "coach" ? await loadMatchWorkflow(supabase, context.teamId, context.seasonId, id) : null;
  const summary = workflow ? summarizeResponses(workflow.players) : null;
  const resting = (await searchParams).tab === "resting";
  const visible = roster.filter(p => resting ? !p.selected && p.isActive : p.selected);
  const status = { upcoming: "Planerad", completed: "Genomförd", cancelled: "Inställd" }[match.status];
  return <AppShell currentItem="Matcher" role={context.role}><article className="mx-auto max-w-2xl space-y-5">
    <Link href="/matches" className="inline-flex min-h-11 items-center font-semibold text-blue-700">← Till matcher</Link>
    <section className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <p className="text-sm font-semibold text-blue-800">{status}</p><h1 className="mt-3 break-words text-3xl font-bold"><OpponentLabel opponent={match.opponent} size="lg" /></h1>
      <p className="mt-4">{formatStockholmDateTime(match.startsAt)}</p><p className="mt-1 break-words text-slate-600">{match.location ?? "Plats ej angiven"}</p>
      <p className="mt-3 text-sm">Grundplan: {match.targetPlayers} platser · {context.seasonName}</p>
      {workflow?.phase === "week" && summary ? <p className="mt-4 rounded-xl bg-blue-50 p-3 font-semibold">{summary.accepted} ja · {summary.pending} inväntar svar · {summary.remaining} lediga platser</p> : null}
      {workflow && match.status !== "cancelled" ? <Link href={`/matches/${id}/week`} className="mt-5 inline-flex min-h-12 w-full items-center justify-center rounded-xl bg-blue-700 px-4 py-3 font-semibold text-white">{workflow.historyRequired ? "Komplettera tidigare kallelser" : match.status === "completed" ? "Visa eller rätta deltagandet" : workflow.phase === "week" ? "Hantera matchveckan" : "Starta matchveckan"}</Link> : null}
      {workflow?.phase === "planning" && match.status === "upcoming" && Date.parse(match.startsAt) > Date.parse(now) ? <Link href={`/matches/${id}/adjust`} className="mt-2 inline-flex min-h-11 items-center text-sm font-semibold text-blue-700">Justera grundplanen före kallelser</Link> : null}
    </section>
    {workflow && match.status === "upcoming" ? <CancelMatchForm action={`/matches/${id}/week/save`} revision={workflow.revision} requestId={randomUUID()} /> : null}
    {workflow && match.status === "cancelled" ? <Link href="/matches/allocation/preview" className="inline-flex min-h-11 items-center font-semibold text-blue-700">Omfördela resterande grundplaner</Link> : null}
    <section className="rounded-2xl bg-white p-5"><nav aria-label="Laguttagning" className="flex border-b border-slate-200"><Link href={`/matches/${id}`} aria-current={!resting ? "page" : undefined} className="min-h-11 px-3 py-3 font-semibold">Lag ({roster.filter(p => p.selected).length})</Link><Link href={`/matches/${id}?tab=resting`} aria-current={resting ? "page" : undefined} className="min-h-11 px-3 py-3 font-semibold">Står över ({roster.filter(p => !p.selected && p.isActive).length})</Link></nav>
      {visible.length ? <ul className="divide-y divide-slate-100">{visible.map(p => <li key={p.id} className="flex min-h-14 items-center justify-between gap-3 py-3"><span className="min-w-0 break-words font-medium">{p.name}{p.selectionType === "extra" && p.selected ? <span className="ml-2 text-xs text-violet-700">Extra</span> : null}{context.role === "coach" && match.status === "completed" && p.selected ? <span className="ml-2 text-xs text-emerald-700">{p.played ? "Spelade" : "Deltog inte"}</span> : null}</span>{context.role === "coach" ? <span className="shrink-0 text-xs text-slate-500">Nivå {p.level}</span> : null}</li>)}</ul> : <p className="py-5 text-sm text-slate-600">{resting ? "Ingen står över." : "Inga spelare i laget ännu."}</p>}
      {workflow?.phase === "week" ? <p className="mt-4 text-xs text-slate-500">Laget visar ja och väntande svar. Faktiskt deltagande registreras efter matchen.</p> : null}
    </section>
  </article></AppShell>;
}
