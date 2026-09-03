import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadMatch } from "@/features/matches/load-matches";
import { loadMatchRoster } from "@/features/selections/load-match-roster";
import { loadManualAdjustmentFingerprint } from "@/features/selections/manual-adjustment";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createClient } from "@/lib/supabase/server";
import { AdjustmentForm } from "./adjustment-form";

export const dynamic = "force-dynamic";

export default async function AdjustMatchPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ error?: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const userId = await getVerifiedUserId();
  if (!userId) redirect(`/login?next=${encodeURIComponent(`/matches/${id}/adjust`)}`);
  const context = await loadTeamContext(supabase);
  if (!context || context.role !== "coach") redirect("/access-denied");
  const match = await loadMatch(supabase, context.teamId, context.seasonId, id);
  if (!match) notFound();
  if (match.status !== "upcoming" || Date.parse(match.startsAt) <= Date.parse(new Date().toISOString())) redirect(`/matches/${id}`);
  const [roster, fingerprint] = await Promise.all([
    loadMatchRoster(supabase, context.teamId, context.seasonId, id),
    loadManualAdjustmentFingerprint(supabase, context.teamId, context.seasonId, id),
  ]);
  const leveledRoster=roster.filter((player):player is typeof player&{level:NonNullable<typeof player.level>}=>player.level!==null);
  if(leveledRoster.length!==roster.length)throw new Error("Spelarnivåer saknas i tränarvyn.");
  const outgoing = leveledRoster.filter((player) => player.selectionType === "regular" && player.selectionSource === "automatic" && player.selectionStatus === "selected");
  const incoming = leveledRoster.filter((player) => player.isActive && player.selectionStatus === null);
  const error = (await searchParams).error;

  return <AppShell currentItem="Matcher" role={context.role}><main className="mx-auto max-w-2xl">
    <Link href={`/matches/${id}`} className="inline-flex min-h-11 items-center text-sm font-semibold text-blue-700">← Till matchen</Link>
    <h1 className="mt-2 text-3xl font-bold text-slate-950">Justera ordinarie lag</h1>
    <p className="mt-2 text-slate-600">{match.opponent}. Bytet gäller endast denna match och påverkar inte extra inhopp.</p>
    {error ? <div role="alert" className="mt-5 rounded-xl border border-amber-300 bg-amber-50 p-4 text-sm text-amber-950">{error === "stale" ? "Laget ändrades innan bytet sparades. Kontrollera de aktuella valen och försök igen." : "Bytet är inte längre giltigt. Kontrollera laget och försök igen."}</div> : null}
    {outgoing.length === 0 || incoming.length === 0 ? <section className="mt-6 rounded-xl bg-white p-5 shadow-sm"><h2 className="font-semibold text-slate-950">Inget byte kan göras just nu</h2><p className="mt-2 text-sm text-slate-600">Det behövs både en automatiskt uttagen spelare och en valbar ersättare.</p></section> : <div className="mt-6"><AdjustmentForm action={`/matches/${id}/adjust/save`} fingerprint={fingerprint} outgoing={outgoing} incoming={incoming} /></div>}
  </main></AppShell>;
}
