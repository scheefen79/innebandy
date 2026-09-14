import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { loadTrainingAttendance } from "@/features/trainings/training-attendance";
import { formatTrainingDate } from "@/features/trainings/training-time";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

function CheckIcon() {
  return <svg aria-hidden="true" className="h-4 w-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="3"><path strokeLinecap="round" strokeLinejoin="round" d="m5 12 4 4L19 6" /></svg>;
}

export default async function TrainingAttendancePage({ searchParams }: { searchParams: Promise<{ change?: string; open?: string }> }) {
  const supabase = await createClient();
  const userId = await getVerifiedUserId();
  if (!userId) redirect("/login?next=/training-attendance");
  const context = await loadTeamContext(supabase);
  if (!context) redirect("/access-denied");
  const [trainings, query] = await Promise.all([loadTrainingAttendance(supabase, context.teamId, context.seasonId), searchParams]);
  // Server-renderad och dynamisk; dagens tid väljer svarbara träningar för denna request.
  // eslint-disable-next-line react-hooks/purity
  const now = Date.now();

  return <AppShell currentItem="Tränarnärvaro" role={context.role}><main className="mx-auto max-w-3xl">
    <header><p className="text-sm font-semibold text-blue-700">{context.seasonName}</p><h1 className="mt-1 text-3xl font-bold text-slate-950">Tränarnärvaro</h1><p className="mt-2 text-sm text-slate-600">Öppna en träning för att ange eller ändra ditt eget svar.</p></header>
    {query.change === "saved" ? <p role="status" className="mt-5 rounded-xl bg-emerald-50 p-3 text-sm text-emerald-900">Ditt svar är sparat.</p> : null}
    {query.change === "invalid" ? <p role="alert" className="mt-5 rounded-xl bg-red-50 p-3 text-sm text-red-900">Svaret kunde inte sparas. Träningen kan vara genomförd eller inte längre tillgänglig.</p> : null}
    <section className="mt-6"><h2 className="text-xl font-bold text-slate-950">Översikt</h2><p className="mt-1 text-sm text-slate-600">Visar enbart träningar. Antalet avser dem som har angett att de kommer.</p>
      {trainings.length ? <div className="mt-4 overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm"><div className="grid grid-cols-[minmax(0,1fr)_auto] gap-3 border-b border-slate-200 bg-slate-50 px-4 py-3 text-xs font-semibold uppercase tracking-wide text-slate-600"><span>Datum</span><span>På plats</span></div><ul>{trainings.map((training) => {
        const ownResponse = training.responses.find((response) => response.userId === userId);
        const coming = training.responses.filter((response) => response.status === "coming");
        const canRespond = Date.parse(training.endsAt) > now && training.status !== "completed";
        return <li key={training.id} className="border-b border-slate-200 last:border-b-0"><details className="group" open={query.open === training.id}><summary className="grid min-h-14 cursor-pointer grid-cols-[minmax(0,1fr)_auto] items-center gap-3 px-4 py-3 marker:content-none hover:bg-slate-50 focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-blue-700"><time dateTime={training.startsAt} className="font-semibold capitalize text-slate-950">{formatTrainingDate(training.startsAt)}</time><span className="shrink-0 rounded-full bg-emerald-50 px-3 py-1 text-sm font-semibold text-emerald-900">{coming.length} kommer</span></summary><div className="border-t border-slate-100 bg-slate-50 px-4 py-4"><section aria-label="Tränare som kommer"><p className="text-sm font-semibold text-slate-950">Kommer ({coming.length})</p>{coming.length ? <ul className="mt-2 flex flex-wrap gap-2">{coming.map((response)=><li key={response.userId} className="rounded-full bg-white px-3 py-1 text-sm text-slate-700 shadow-sm">{response.name}</li>)}</ul> : <p className="mt-1 text-sm text-slate-600">Ingen har angett att den kommer ännu.</p>}</section>{canRespond ? <form action="/training-attendance/save" method="post" className="mt-4 grid grid-cols-2 gap-2"><input type="hidden" name="training_id" value={training.id} /><button type="submit" name="status" value="coming" className={`flex min-h-11 items-center justify-center gap-2 rounded-xl px-3 text-sm font-semibold ${ownResponse?.status === "coming" ? "bg-emerald-700 text-white" : "bg-emerald-50 text-emerald-900"}`}>{ownResponse?.status === "coming" ? <CheckIcon /> : null}Jag kommer</button><button type="submit" name="status" value="absent" className={`flex min-h-11 items-center justify-center gap-2 rounded-xl px-3 text-sm font-semibold ${ownResponse?.status === "absent" ? "bg-slate-700 text-white" : "bg-slate-100 text-slate-800"}`}>{ownResponse?.status === "absent" ? <CheckIcon /> : null}Jag är frånvarande</button></form> : <p className="mt-4 text-sm text-slate-600">Svar kan inte längre ändras för den här träningen.</p>}</div></details></li>;
      })}</ul></div> : <p className="mt-4 rounded-xl border border-dashed border-slate-300 bg-white p-4 text-sm text-slate-600">Det finns inga träningar i den aktiva säsongen.</p>}</section>
  </main></AppShell>;
}
