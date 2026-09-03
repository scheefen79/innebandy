import Link from "next/link";
import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadMatches } from "@/features/matches/load-matches";
import { formatStockholmDateTime } from "@/features/matches/match-time";
import { loadPlayerList } from "@/features/players/load-player-list";
import {
  allocationErrorText,
  allocationWarningText,
  loadAllocationPreview,
} from "@/features/selections/allocation-preview";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createClient } from "@/lib/supabase/server";
import { SaveAllocationButton } from "./save-allocation-button";

export const dynamic = "force-dynamic";

export default async function AllocationPreviewPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const supabase = await createClient();
  const userId = await getVerifiedUserId();
  if (!userId) redirect("/login?next=/matches/allocation/preview");
  const context = await loadTeamContext(supabase);
  if (!context || context.role !== "coach") redirect("/access-denied");

  const boundary = new Date().toISOString();
  const [previewResult, matches, playerList] = await Promise.all([
    loadAllocationPreview(supabase, context.teamId, context.seasonId, boundary),
    loadMatches(supabase, context.teamId, context.seasonId, "upcoming", boundary),
    loadPlayerList(supabase, context.teamId),
  ]);
  const error = (await searchParams).error;

  if (!previewResult.ok) {
    return <AppShell currentItem="Matcher" role={context.role}><div className="mx-auto max-w-2xl"><Link href="/matches" className="inline-flex min-h-11 items-center text-sm font-semibold text-blue-700">← Till matcher</Link><div role="alert" className="mt-4 rounded-2xl border border-red-200 bg-white p-6"><h1 className="text-xl font-bold text-slate-950">Fördelningen kunde inte skapas</h1><ul className="mt-3 list-disc space-y-1 pl-5 text-sm text-red-800">{previewResult.errors.map((item, index) => <li key={`${item.code}-${index}`}>{allocationErrorText[item.code]}</li>)}</ul></div></div></AppShell>;
  }

  const matchById = new Map(matches.map((match) => [match.id, match]));
  const playerById = new Map(playerList.players.map((player) => [player.id, player]));

  return <AppShell currentItem="Matcher" role={context.role}><div className="mx-auto max-w-3xl">
    <Link href="/matches" className="inline-flex min-h-11 items-center text-sm font-semibold text-blue-700">← Till matcher</Link>
    <h1 className="mt-2 text-3xl font-bold text-slate-950">Förhandsgranska fördelning</h1>
    <p className="mt-2 text-sm text-slate-600">Kontrollera lagen innan hela fördelningen sparas.</p>
    {error === "stale" ? <div role="alert" className="mt-5 rounded-xl border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900">Underlaget ändrades efter förhandsgranskningen. Kontrollera den nya fördelningen och spara igen.</div> : null}
    {previewResult.preview.warnings.length ? <section className="mt-5 rounded-xl border border-amber-200 bg-amber-50 p-4"><h2 className="font-semibold text-amber-950">Varningar</h2><ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-amber-900">{previewResult.preview.warnings.map((warning, index) => <li key={`${warning.code}-${index}`}>{allocationWarningText(warning)}</li>)}</ul></section> : null}
    {matches.length === 0 ? <div className="mt-6 rounded-2xl border border-dashed border-slate-300 bg-white p-6 text-center"><h2 className="font-semibold text-slate-900">Inga framtida matcher</h2><p className="mt-2 text-sm text-slate-600">Skapa en kommande match innan du genererar fördelningen.</p></div> : <div className="mt-6 space-y-4">{previewResult.preview.allocations.map((allocation) => {
      const match = matchById.get(allocation.matchId);
      return <section key={allocation.matchId} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><div className="flex flex-wrap items-start justify-between gap-2"><div><h2 className="font-semibold text-slate-950">{match?.opponent ?? "Match"}</h2>{match ? <p className="mt-1 text-sm text-slate-600">{formatStockholmDateTime(match.startsAt)}</p> : null}</div><span className="rounded-full bg-green-50 px-2 py-1 text-xs font-semibold text-green-800">{allocation.playerIds.length} / {match?.targetPlayers ?? allocation.playerIds.length}</span></div><ul className="mt-4 grid gap-2 sm:grid-cols-2">{allocation.playerIds.map((playerId) => <li key={playerId} className="min-w-0 rounded-xl bg-slate-50 px-3 py-2 text-sm"><span className="block truncate font-medium text-slate-900">{playerById.get(playerId)?.name ?? "Okänd spelare"}</span><span className="text-xs text-slate-500">Nivå {playerById.get(playerId)?.level ?? "–"}</span></li>)}</ul></section>;
    })}</div>}
    {matches.length ? <form action="/matches/allocation/save" method="post" className="sticky bottom-20 mt-6 rounded-2xl border border-slate-200 bg-white/95 p-4 shadow-lg backdrop-blur md:bottom-4"><input type="hidden" name="fingerprint" value={previewResult.preview.fingerprint} /><SaveAllocationButton /></form> : null}
  </div></AppShell>;
}
