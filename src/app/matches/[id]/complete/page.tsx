import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadMatch } from "@/features/matches/load-matches";
import { loadMatchCompletionSource } from "@/features/selections/match-completion";
import { loadMatchRoster } from "@/features/selections/load-match-roster";
import { loadTeamContext } from "@/lib/auth/team-context";
import { createClient } from "@/lib/supabase/server";
import { CompletionForm } from "./completion-form";

export const dynamic = "force-dynamic";

export default async function CompleteMatchPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  if (!data?.claims?.sub) redirect(`/login?next=${encodeURIComponent(`/matches/${id}/complete`)}`);
  const context = await loadTeamContext(supabase);
  if (!context) redirect("/access-denied");
  const match = await loadMatch(supabase, context.teamId, context.seasonId, id);
  if (!match) notFound();
  if (match.status !== "upcoming" || Date.parse(match.startsAt) > Date.parse(new Date().toISOString())) redirect(`/matches/${id}`);
  const roster = await loadMatchRoster(supabase, context.teamId, context.seasonId, id);
  const regularCount = roster.filter((player) => player.selectionType === "regular" && player.selectionStatus === "selected").length;
  if (regularCount !== match.targetPlayers) redirect(`/matches/${id}`);
  const source = await loadMatchCompletionSource(supabase, context.teamId, context.seasonId, id);
  const error = (await searchParams).error;
  return <AppShell currentItem="Matcher"><main className="mx-auto max-w-2xl">
    <Link href={`/matches/${id}`} className="inline-flex min-h-11 items-center text-sm font-semibold text-blue-700">← Till matchen</Link>
    <h1 className="mt-2 text-3xl font-bold text-slate-950">Genomför match</h1>
    <p className="mt-2 text-slate-600">{match.opponent}. Alla uttagna är markerade som spelade. Avmarkera dem som inte deltog.</p>
    {error ? <div role="alert" className="mt-5 rounded-xl border border-amber-300 bg-amber-50 p-4 text-sm text-amber-950">{error === "stale" ? "Uttagningen ändrades innan matchen sparades. Kontrollera deltagarna igen." : error === "completed" ? "Matchen har redan genomförts med ett annat deltagande." : "Deltagandet kunde inte sparas. Kontrollera matchen och försök igen."}</div> : null}
    <div className="mt-6"><CompletionForm action={`/matches/${id}/complete/save`} fingerprint={source.fingerprint} participants={source.participants} /></div>
  </main></AppShell>;
}
