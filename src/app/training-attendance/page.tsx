import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadTrainingAttendance, trainingAttendanceStatusText } from "@/features/trainings/training-attendance";
import { formatTrainingTime } from "@/features/trainings/training-time";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function TrainingAttendancePage({ searchParams }: { searchParams: Promise<{ change?: string }> }) {
  const supabase = await createClient();
  const userId = await getVerifiedUserId();
  if (!userId) redirect("/login?next=/training-attendance");
  const context = await loadTeamContext(supabase);
  if (!context) redirect("/access-denied");
  const [trainings, query] = await Promise.all([loadTrainingAttendance(supabase, context.teamId, context.seasonId), searchParams]);
  // Server-renderad och dynamisk; dagens tid väljer svarbara träningar för denna request.
  // eslint-disable-next-line react-hooks/purity
  const now = Date.now();
  const upcoming = trainings.filter((training) => Date.parse(training.endsAt) > now && training.status !== "completed");

  return <AppShell currentItem="Närvaro" role={context.role}><main className="mx-auto max-w-3xl">
    <header><p className="text-sm font-semibold text-blue-700">{context.seasonName}</p><h1 className="mt-1 text-3xl font-bold text-slate-950">Tränarnärvaro</h1><p className="mt-2 text-sm text-slate-600">Ange dina egna svar och se vilka som planerar att vara på plats.</p></header>
    {query.change === "saved" ? <p role="status" className="mt-5 rounded-xl bg-emerald-50 p-3 text-sm text-emerald-900">Ditt svar är sparat.</p> : null}
    {query.change === "invalid" ? <p role="alert" className="mt-5 rounded-xl bg-red-50 p-3 text-sm text-red-900">Svaret kunde inte sparas. Träningen kan vara genomförd eller inte längre tillgänglig.</p> : null}
    <section className="mt-6"><h2 className="text-xl font-bold text-slate-950">Min planerade närvaro</h2><p className="mt-1 text-sm text-slate-600">Du kan ändra ditt svar fram till att träningen markeras som genomförd.</p>
      {upcoming.length ? <ul className="mt-4 space-y-3">{upcoming.map((training) => {
        const ownResponse = training.responses.find((response) => response.userId === userId);
        return <li key={training.id} className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm"><p className="text-xs font-semibold text-blue-700">Block {training.themeBlock}</p><h3 className="mt-1 font-semibold text-slate-950">{training.focus}</h3><p className="mt-1 text-sm text-slate-600">{formatTrainingTime(training.startsAt, training.endsAt)}</p><p className="mt-3 text-sm font-medium text-slate-800">{ownResponse ? `Ditt svar: ${trainingAttendanceStatusText(ownResponse.status)}` : "Ditt svar: Inte angivet"}</p><form action="/training-attendance/save" method="post" className="mt-3 grid grid-cols-2 gap-2"><input type="hidden" name="training_id" value={training.id} /><button type="submit" name="status" value="coming" className={`min-h-11 rounded-xl px-3 text-sm font-semibold ${ownResponse?.status === "coming" ? "bg-emerald-700 text-white" : "bg-emerald-50 text-emerald-900"}`}>Jag kommer</button><button type="submit" name="status" value="absent" className={`min-h-11 rounded-xl px-3 text-sm font-semibold ${ownResponse?.status === "absent" ? "bg-slate-700 text-white" : "bg-slate-100 text-slate-800"}`}>Jag är frånvarande</button></form></li>;
      })}</ul> : <p className="mt-4 rounded-xl border border-dashed border-slate-300 bg-white p-4 text-sm text-slate-600">Det finns inga kommande träningar att svara på.</p>}</section>
    <section className="mt-9"><h2 className="text-xl font-bold text-slate-950">Översikt över träningar</h2><p className="mt-1 text-sm text-slate-600">Visar tränare som har angett att de kommer. Frånvarande och obesvarade räknas inte med.</p>
      {trainings.length ? <ul className="mt-4 space-y-3">{trainings.map((training) => { const coming = training.responses.filter((response) => response.status === "coming"); return <li key={training.id} className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm"><div className="flex items-start justify-between gap-3"><div><p className="text-xs font-semibold text-blue-700">Block {training.themeBlock}</p><h3 className="mt-1 font-semibold text-slate-950">{training.focus}</h3><p className="mt-1 text-sm text-slate-600">{formatTrainingTime(training.startsAt, training.endsAt)}</p></div><span className="shrink-0 rounded-full bg-emerald-50 px-3 py-1 text-sm font-semibold text-emerald-900">{coming.length} kommer</span></div>{coming.length ? <p className="mt-3 text-sm text-slate-700">{coming.map((response) => response.name).join(", ")}</p> : <p className="mt-3 text-sm text-slate-600">Ingen har angett att den kommer ännu.</p>}</li>; })}</ul> : <p className="mt-4 rounded-xl border border-dashed border-slate-300 bg-white p-4 text-sm text-slate-600">Det finns inga träningar i den aktiva säsongen.</p>}</section>
  </main></AppShell>;
}
