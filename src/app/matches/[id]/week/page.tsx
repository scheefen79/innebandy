import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { randomUUID } from "node:crypto";
import { AppShell } from "@/components/app-shell";
import { loadMatch } from "@/features/matches/load-matches";
import { formatStockholmDateTime } from "@/features/matches/match-time";
import { loadMatchWorkflow, workflowErrorText } from "@/features/match-workflow/workflow";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createClient } from "@/lib/supabase/server";
import { WorkflowView } from "./workflow-view";
export const dynamic = "force-dynamic";
export default async function MatchWeekPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string; saved?: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  if (!await getVerifiedUserId()) redirect("/login?next=/matches");
  const context = await loadTeamContext(supabase);
  if (!context || context.role !== "coach") redirect("/access-denied");
  const match = await loadMatch(supabase, context.teamId, context.seasonId, id);
  if (!match) notFound();
  const workflow = await loadMatchWorkflow(supabase, context.teamId, context.seasonId, id);
  const query = await searchParams;
  return <AppShell currentItem="Matcher" role={context.role}><article className="mx-auto max-w-3xl space-y-5">
    <Link href={`/matches/${id}`} className="inline-flex min-h-11 items-center font-semibold text-blue-700">← Till matchen</Link>
    <header><h1 className="break-words text-2xl font-bold">{match.opponent}</h1><p className="text-sm text-slate-600">{formatStockholmDateTime(match.startsAt)}</p></header>
    {query.saved ? <p role="status" className="rounded-xl bg-emerald-50 p-4 text-emerald-900">Ändringen är sparad.</p> : null}
    {query.error ? <p role="alert" className="rounded-xl bg-amber-50 p-4 text-amber-950">{workflowErrorText[query.error] ?? "Det gick inte att spara ändringen."}</p> : null}
    <WorkflowView key={`${workflow.revision}-${query.error ?? ""}`} workflow={workflow} action={`/matches/${id}/week/save`} requestId={randomUUID()} now={new Date().toISOString()} />
  </article></AppShell>;
}
