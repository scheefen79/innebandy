import Link from "next/link";
import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { formatStockholmDateTime } from "@/features/matches/match-time";
import { loadMatches } from "@/features/matches/load-matches";
import { loadTeamContext } from "@/lib/auth/team-context";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function MatchesPage({ searchParams }: { searchParams: Promise<{ allocation?: string; view?: string }> }) {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  if (!data?.claims?.sub) redirect("/login?next=/matches");
  const context = await loadTeamContext(supabase);
  if (!context) redirect("/access-denied");

  const resolvedSearchParams = await searchParams;
  const filter = resolvedSearchParams.view === "all" ? "all" : "upcoming";
  const matches = await loadMatches(supabase, context.teamId, context.seasonId, filter, new Date().toISOString());

  return <AppShell currentItem="Matcher">
    <div className="mx-auto max-w-3xl">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div><p className="text-sm font-semibold text-blue-700">{context.seasonName}</p><h1 className="mt-1 text-3xl font-bold text-slate-950">Matcher</h1></div>
        <div className="flex flex-wrap gap-2"><Link href="/matches/allocation/preview" className="flex min-h-11 items-center rounded-xl border border-blue-700 px-4 py-2 text-sm font-semibold text-blue-700 hover:bg-blue-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-700">Generera fördelning</Link><Link href="/matches/new" className="flex min-h-11 items-center rounded-xl bg-blue-700 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-700">Ny match</Link></div>
      </div>
      {resolvedSearchParams.allocation === "saved" ? <p role="status" className="mt-5 rounded-xl border border-green-200 bg-green-50 p-4 text-sm font-medium text-green-900">Fördelningen är sparad.</p> : null}
      <nav aria-label="Filtrera matcher" className="mt-6 flex gap-2 border-b border-slate-200">
        <Link href="/matches" aria-current={filter === "upcoming" ? "page" : undefined} className={`min-h-11 px-3 py-3 text-sm font-semibold ${filter === "upcoming" ? "border-b-2 border-blue-700 text-blue-700" : "text-slate-600"}`}>Kommande</Link>
        <Link href="/matches?view=all" aria-current={filter === "all" ? "page" : undefined} className={`min-h-11 px-3 py-3 text-sm font-semibold ${filter === "all" ? "border-b-2 border-blue-700 text-blue-700" : "text-slate-600"}`}>Alla</Link>
      </nav>
      {matches.length === 0 ? <section className="mt-6 rounded-2xl border border-dashed border-slate-300 bg-white p-6 text-center"><h2 className="font-semibold text-slate-900">{filter === "upcoming" ? "Inga kommande matcher" : "Säsongen saknar matcher"}</h2><p className="mt-2 text-sm text-slate-600">{filter === "upcoming" ? "Visa alla matcher eller skapa nästa match." : "Skapa en match för att börja planera truppen."}</p></section> :
        <ul className="mt-5 space-y-3">{matches.map((match) => <li key={match.id}><Link href={`/matches/${match.id}`} className="block min-w-0 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm hover:border-blue-300 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-700"><div className="flex min-w-0 items-start justify-between gap-3"><div className="min-w-0"><h2 className="truncate font-semibold text-slate-950">{match.opponent}</h2><p className="mt-1 text-sm text-slate-600">{formatStockholmDateTime(match.startsAt)}</p><p className="mt-1 truncate text-sm text-slate-500">{match.location ?? "Plats ej angiven"}</p></div><div className="shrink-0 text-right"><span className="block rounded-full bg-blue-50 px-2 py-1 text-xs font-semibold text-blue-800">{match.status === "upcoming" ? "Planerad" : match.status === "completed" ? "Genomförd" : "Inställd"}</span><span className="mt-2 block text-xs font-semibold text-slate-600">{match.selectedPlayers} / {match.targetPlayers}</span></div></div></Link></li>)}</ul>}
    </div>
  </AppShell>;
}
