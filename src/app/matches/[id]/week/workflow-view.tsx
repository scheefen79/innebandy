"use client";
import { useState } from "react";
import { rankExtraCandidates, responseLabels, summarizeResponses, type MatchResponse, type MatchWorkflow, type WorkflowAction } from "@/features/match-workflow/workflow";

const button = "min-h-12 rounded-xl bg-blue-700 px-4 py-3 font-semibold text-white disabled:bg-slate-300";
export function WorkflowView({ workflow, action, requestId, now }: { workflow: MatchWorkflow; action: string; requestId: string; now: string }) {
  const [responses, setResponses] = useState<Record<string, MatchResponse>>(() => Object.fromEntries(workflow.players.map(p => [p.id, p.response])));
  const [selected, setSelected] = useState<string[]>(() => workflow.historyRequired ? workflow.players.filter(p => p.inPlan).map(p => p.id) : workflow.players.filter(p => workflow.status === "completed" ? p.played : p.response === "accepted").map(p => p.id));
  const [pending, setPending] = useState(false);
  const summary = summarizeResponses(workflow.players.map(p => ({ response: responses[p.id] })));
  const changed = workflow.players.filter(p => responses[p.id] !== p.response);
  const candidates = rankExtraCandidates(workflow.players);
  const planned = workflow.players.filter(p => p.inPlan);
  const extras = workflow.players.filter(p => !p.inPlan).sort((a, b) => {
    const ai = candidates.indexOf(a.id), bi = candidates.indexOf(b.id);
    return (ai < 0 ? Number.MAX_SAFE_INTEGER : ai) - (bi < 0 ? Number.MAX_SAFE_INTEGER : bi) || a.rotationOrder - b.rotationOrder;
  });
  const hidden = (type: WorkflowAction) => <><input type="hidden" name="action" value={type} /><input type="hidden" name="revision" value={workflow.revision} /><input type="hidden" name="requestId" value={requestId} /></>;
  const toggle = (id: string) => setSelected(current => current.includes(id) ? current.filter(value => value !== id) : [...current, id]);
  if (workflow.status === "cancelled") return <p className="rounded-xl bg-white p-5">Matchen är inställd. Kallelserna räknas inte i rättvisan.</p>;
  if (workflow.historyRequired) return <form action={action} method="post" onSubmit={() => setPending(true)} className="space-y-4 rounded-2xl bg-white p-5">
    {hidden("history")}<h2 className="text-xl font-semibold">Komplettera tidigare kallelser</h2>
    <p className="text-sm text-slate-600">Markera alla som fick en ordinarie kallelse, även de som tackade nej eller vars kallelse drogs in. Befintliga uttagningar är endast förslag. Spelat deltagande ändras inte.</p>
    {workflow.players.map(p => <label key={p.id} className="flex min-h-12 items-center gap-3 border-b border-slate-100 py-2"><input type="checkbox" name="selectedPlayerId" value={p.id} checked={selected.includes(p.id)} onChange={() => toggle(p.id)} className="h-5 w-5" /><span className="min-w-0 break-words">{p.name}{!p.active ? <span className="ml-2 text-xs text-slate-500">Inaktiv</span> : null}</span></label>)}
    <label className="flex min-h-12 items-center gap-3"><input type="checkbox" name="historyConfirmed" required className="h-5 w-5" />Jag har kontrollerat vilka som kallades, även om ingen kallades.</label>
    <button disabled={pending} className={button}>{pending ? "Sparar…" : "Bekräfta historiken"}</button>
  </form>;
  if (workflow.phase === "planning" || workflow.phase === "legacy" && workflow.status === "upcoming") return <section className="space-y-4 rounded-2xl bg-white p-5">
    <h2 className="text-xl font-semibold">Fas 1 · Grundplan</h2><p className="text-sm text-slate-600">Starta matchveckan när ni ska börja kalla spelare. Grundplanen bevaras och omfördelningen lämnar denna match orörd.</p>
    {planned.length ? <ul className="space-y-2">{planned.map(p => <li key={p.id} className="break-words">{p.name}</li>)}</ul> : <p>Ingen grundplan ännu. Du kan ändå starta matchveckan och kalla extra spelare.</p>}
    <form action={action} method="post" onSubmit={() => setPending(true)}>{hidden("start")}<button disabled={pending} className={button}>Starta matchveckan</button></form>
  </section>;
  const isLocked = workflow.status === "completed";
  return <div className="space-y-5">
    {!isLocked ? <form action={action} method="post" onSubmit={() => setPending(true)} className="space-y-5 rounded-2xl bg-white p-5">
      {hidden("responses")}<h2 className="text-xl font-semibold">Fas 2 · Kallelser och svar</h2>
      <p className="text-sm text-slate-600">Skicka kallelser i ert vanliga verktyg och registrera dem här. Ett nej eller en indragen kallelse frigör plats. Den erbjudna ordinarie matchen räknas fortfarande.</p>
      {workflow.players.some(p => p.totals.historyComplete === false) ? <p role="status" className="rounded-xl bg-amber-50 p-3 text-sm">Tidigare kallelser är inte fullständigt bekräftade. Antal och förslag som extra är preliminära tills historiken är genomgången.</p> : null}
      <p aria-live="polite" className={`rounded-xl p-3 font-semibold ${summary.remaining < 0 ? "bg-red-50 text-red-800" : "bg-blue-50 text-blue-900"}`}>{summary.accepted} ja · {summary.pending} inväntar svar · {summary.remaining} lediga platser</p>
      {changed.map(p => <input key={p.id} type="hidden" name="playerId" value={p.id} />)}
      {[{ title: "Ordinarie i grundplanen", players: planned }, { title: "Extra och övriga spelare", players: extras }].map(group => <fieldset key={group.title}><legend className="font-semibold">{group.title}</legend>
        {group.players.length === 0 ? <p className="mt-3 text-sm text-slate-500">Inga spelare i denna grupp.</p> : group.players.map(p => <div key={p.id} className="space-y-2 border-b border-slate-100 py-3">
          <label htmlFor={`response-${p.id}`} className="block break-words font-medium">{p.name}{p.id === candidates[0] ? <span className="ml-2 text-xs text-violet-700">Förslag som extra</span> : null}</label>
          <p className="text-xs text-slate-600">{p.totals.offeredRegular} {p.totals.historyComplete === false ? "bekräftade ordinarie · ofullständigt" : "erbjudna ordinarie"} · {p.totals.completedExtra} spelade extra · Nivå {p.level}</p>
          <select id={`response-${p.id}`} name={`response:${p.id}`} value={responses[p.id]} onChange={e => setResponses(current => ({ ...current, [p.id]: e.target.value as MatchResponse }))} className="min-h-12 w-full rounded-lg border border-slate-300 bg-white px-3">
            {Object.entries(responseLabels).filter(([value]) => value === "uninvited" ? p.response === "uninvited" : value === "pending" || value === "accepted" ? p.active : p.response !== "uninvited").map(([value, label]) => <option key={value} value={value}>{label}</option>)}
          </select>
        </div>)}
      </fieldset>)}
      <button disabled={pending || changed.length === 0 || summary.remaining < 0} className={`${button} w-full`}>{pending ? "Sparar…" : `Spara ${changed.length} ändringar`}</button>
    </form> : <section className="rounded-xl bg-emerald-50 p-5"><h2 className="font-semibold">Deltagandet är låst</h2><p className="mt-2 text-sm">{workflow.players.filter(p => p.played).length} spelare deltog. En rättning sparas med anledning och historik.</p></section>}
    {isLocked || Date.parse(workflow.startsAt) <= Date.parse(now) ? <form action={action} method="post" onSubmit={() => setPending(true)} className="space-y-4 rounded-2xl bg-white p-5">
      {hidden(isLocked ? "correct" : "lock")}<h2 className="text-xl font-semibold">{isLocked ? "Rätta deltagande" : "Registrera deltagande och lås"}</h2>
      <p className="text-sm text-slate-600">Markera exakt vilka som spelade, högst tio. Spelare utan erbjuden ordinarie plats registreras som extra.</p>
      {!isLocked && workflow.players.some(p => p.response === "pending") ? <p role="alert" className="rounded-xl bg-amber-50 p-3">Registrera alla väntande svar och spara dem innan du låser deltagandet.</p> : null}
      {workflow.players.filter(p => p.active || p.played || p.offeredRegular || p.response !== "uninvited").map(p => <label key={p.id} className="flex min-h-12 items-center gap-3 border-b border-slate-100 py-2"><input type="checkbox" name="selectedPlayerId" value={p.id} checked={selected.includes(p.id)} onChange={() => toggle(p.id)} className="h-5 w-5" /><span className="min-w-0 break-words">{p.name}<span className="ml-2 text-xs text-slate-500">{p.offeredRegular ? "Ordinarie" : "Extra"}</span></span></label>)}
      {changed.length > 0 ? <p role="status" className="text-sm text-amber-900">Spara ändrade kallelser och svar innan deltagandet sparas.</p> : null}
      <p aria-live="polite" className="font-semibold">{selected.length} deltagare valda</p>
      {isLocked ? <label className="block text-sm font-semibold">Anledning till rättningen<textarea name="reason" required maxLength={500} className="mt-2 min-h-24 w-full rounded-xl border border-slate-300 p-3" /></label> : null}
      <button disabled={pending || selected.length < 1 || selected.length > 10 || changed.length > 0 || !isLocked && workflow.players.some(p => p.response === "pending")} className={`${button} w-full`}>{isLocked ? "Spara rättning" : "Lås deltagandet"}</button>
    </form> : <p className="rounded-xl bg-slate-100 p-4 text-sm">Deltagandet kan låsas efter matchstart. Kallelser och svar kan ändras fram till låsning.</p>}
    {!isLocked ? <details className="rounded-xl bg-white p-4"><summary className="min-h-11 cursor-pointer font-semibold text-red-700">Ställ in matchen</summary><p className="my-3 text-sm">En inställd match räknas inte för rättvisa eller spelat deltagande.</p><form action={action} method="post" onSubmit={() => setPending(true)}>{hidden("cancel")}<button disabled={pending} className="min-h-12 rounded-xl border border-red-300 px-4 text-red-800">Bekräfta inställd match</button></form></details> : null}
    {workflow.events.length ? <details className="rounded-xl bg-white p-4"><summary className="min-h-11 cursor-pointer font-semibold">Ändringshistorik</summary><ul className="space-y-3 text-sm">{workflow.events.map(event => <li key={event.revision}>{new Date(event.at).toLocaleString("sv-SE", { timeZone: "Europe/Stockholm" })} · {({ start: "Matchveckan startad", responses: "Kallelser och svar sparade", lock: "Deltagandet låst", correct: "Deltagandet rättat", history: "Historiken bekräftad", cancel: "Matchen inställd" } as Record<string, string>)[event.action]}{event.reason ? <p className="break-words text-slate-600">{event.reason}</p> : null}</li>)}</ul></details> : null}
  </div>;
}
