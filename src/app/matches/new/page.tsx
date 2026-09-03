import Link from "next/link";
import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createClient } from "@/lib/supabase/server";
import { SubmitButton } from "./submit-button";

export const dynamic = "force-dynamic";

export default async function NewMatchPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const supabase = await createClient();
  const userId = await getVerifiedUserId();
  if (!userId) redirect("/login?next=/matches/new");
  const context = await loadTeamContext(supabase);
  if (!context || context.role !== "coach") redirect("/access-denied");

  const { count, error: countError } = await supabase.from("players").select("id", { count: "exact", head: true })
    .eq("team_id", context.teamId).eq("season_id", context.seasonId).eq("is_active", true);
  if (countError) throw new Error("Det gick inte att räkna aktiva spelare.");
  const defaultTarget = count ? Math.ceil(count / 2) : undefined;
  const error = (await searchParams).error;

  return <AppShell currentItem="Matcher" role={context.role}><div className="mx-auto max-w-xl">
    <Link href="/matches" className="inline-flex min-h-11 items-center text-sm font-semibold text-blue-700">← Till matcher</Link>
    <h1 className="mt-2 text-3xl font-bold text-slate-950">Ny match</h1><p className="mt-2 text-sm text-slate-600">Datum och tid anges i svensk tid.</p>
    {error ? <div role="alert" className="mt-5 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-800">{error === "conflict" ? "Formuläret har redan använts med andra uppgifter. Ladda om sidan och försök igen." : error}</div> : null}
    <form action="/matches/create" method="post" className="mt-6 space-y-5 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <input type="hidden" name="request_id" value={crypto.randomUUID()} />
      <label className="block"><span className="text-sm font-semibold text-slate-800">Motståndare</span><input required maxLength={100} name="opponent" autoComplete="off" className="mt-2 min-h-11 w-full rounded-xl border border-slate-300 px-3 text-base focus:border-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-200" /></label>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2"><label className="block"><span className="text-sm font-semibold text-slate-800">Datum</span><input required type="date" name="date" className="mt-2 min-h-11 w-full rounded-xl border border-slate-300 px-3 text-base" /></label><label className="block"><span className="text-sm font-semibold text-slate-800">Tid</span><input required type="time" name="time" className="mt-2 min-h-11 w-full rounded-xl border border-slate-300 px-3 text-base" /></label></div>
      <label className="block"><span className="text-sm font-semibold text-slate-800">Plats <span className="font-normal text-slate-500">(valfritt)</span></span><input maxLength={200} name="location" autoComplete="off" className="mt-2 min-h-11 w-full rounded-xl border border-slate-300 px-3 text-base" /></label>
      <label className="block"><span className="text-sm font-semibold text-slate-800">Antal matchplatser</span><input required type="number" min="1" step="1" name="target_players" defaultValue={defaultTarget} className="mt-2 min-h-11 w-full rounded-xl border border-slate-300 px-3 text-base" /><span className="mt-2 block text-xs text-slate-500">Förslag: hälften av de aktiva spelarna, avrundat uppåt.</span></label>
      {!defaultTarget ? <p className="rounded-xl bg-amber-50 p-3 text-sm text-amber-900">Laget saknar aktiva spelare, så du behöver ange antalet platser själv.</p> : null}
      <SubmitButton />
    </form>
  </div></AppShell>;
}
