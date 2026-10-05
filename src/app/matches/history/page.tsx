import Link from "next/link";
import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadMatches } from "@/features/matches/load-matches";
import { formatStockholmDateTime } from "@/features/matches/match-time";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createClient } from "@/lib/supabase/server";
export const dynamic = "force-dynamic";
export default async function MatchHistoryPage() {
  const supabase = await createClient();
  if (!await getVerifiedUserId()) redirect("/login?next=/matches/history");
  const context = await loadTeamContext(supabase);
  if (!context || context.role !== "coach") redirect("/access-denied");
  const matches = await loadMatches(supabase, context.teamId, context.seasonId, "all", new Date().toISOString());
  const pending = matches.filter(m => m.historyRequired && m.status !== "cancelled");
  return <AppShell currentItem="Matcher" role={context.role}><section className="mx-auto max-w-2xl space-y-5"><Link href="/matches" className="inline-flex min-h-11 items-center font-semibold text-blue-700">← Till matcher</Link><h1 className="text-2xl font-bold">Tidigare ordinarie kallelser</h1><p className="text-sm text-slate-600">Bekräfta vilka som fick en ordinarie kallelse. Befintliga uttagningar är förslag. Spelat deltagande ändras inte. Grundplanen kan genereras när alla matcher här är genomgångna.</p>
    {pending.length ? <><p className="font-semibold">{pending.length} matcher återstår</p><ul className="space-y-3">{pending.map(m => <li key={m.id}><Link href={`/matches/${m.id}/week`} className="block rounded-xl bg-white p-4"><span className="block break-words font-semibold text-blue-700">{m.opponent}</span><span className="text-sm text-slate-600">{formatStockholmDateTime(m.startsAt)}</span></Link></li>)}</ul></> : <div className="rounded-xl bg-emerald-50 p-5"><p className="font-semibold">Historiken är bekräftad</p><Link href="/matches/allocation/preview" className="mt-3 inline-flex min-h-11 items-center font-semibold text-blue-700">Förhandsgranska grundplanen</Link></div>}
  </section></AppShell>;
}
