import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadMatch } from "@/features/matches/load-matches";
import { formatStockholmDateTime } from "@/features/matches/match-time";
import { loadTeamContext } from "@/lib/auth/team-context";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function MatchPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  if (!data?.claims?.sub) redirect(`/login?next=${encodeURIComponent(`/matches/${id}`)}`);
  const context = await loadTeamContext(supabase);
  if (!context) redirect("/access-denied");
  const match = await loadMatch(supabase, context.teamId, context.seasonId, id);
  if (!match) notFound();

  const status = match.status === "upcoming" ? "Planerad" : match.status === "completed" ? "Genomförd" : "Inställd";
  return <AppShell currentItem="Matcher"><article className="mx-auto max-w-2xl">
    <Link href="/matches" className="inline-flex min-h-11 items-center text-sm font-semibold text-blue-700">← Till matcher</Link>
    <div className="mt-2 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
      <span className="rounded-full bg-blue-50 px-3 py-1 text-xs font-semibold text-blue-800">{status}</span>
      <h1 className="mt-4 break-words text-3xl font-bold text-slate-950">{match.opponent}</h1>
      <dl className="mt-7 grid gap-5 sm:grid-cols-2"><div><dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Datum och tid</dt><dd className="mt-1 text-slate-900">{formatStockholmDateTime(match.startsAt)}</dd></div><div><dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Plats</dt><dd className="mt-1 break-words text-slate-900">{match.location ?? "Ej angiven"}</dd></div><div><dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Matchplatser</dt><dd className="mt-1 text-slate-900">{match.targetPlayers}</dd></div><div><dt className="text-xs font-semibold uppercase tracking-wide text-slate-500">Säsong</dt><dd className="mt-1 text-slate-900">{context.seasonName}</dd></div></dl>
      <section className="mt-7 rounded-xl bg-slate-50 p-4"><h2 className="font-semibold text-slate-900">Laguttagning</h2><p className="mt-1 text-sm text-slate-600">Ingen laguttagning har genererats ännu. Den funktionen kommer i nästa implementation.</p></section>
    </div>
  </article></AppShell>;
}
