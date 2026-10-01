"use client";

import { useState } from "react";

type PlayerOption = { id: string; name: string; level: number };

export function AdjustmentForm({
  action,
  fingerprint,
  incoming,
  outgoing,
}: {
  action: string;
  fingerprint: string;
  incoming: PlayerOption[];
  outgoing: PlayerOption[];
}) {
  const [outgoingIds, setOutgoingIds] = useState<string[]>([]);
  const [replacements, setReplacements] = useState<Record<string, string>>({});
  const selectedOutgoing = outgoing.filter((player) => outgoingIds.includes(player.id));
  const pairs = selectedOutgoing.map((player) => ({ out: player, in: incoming.find((candidate) => candidate.id === replacements[player.id]) }));
  const ready = pairs.length > 0 && pairs.every((pair) => pair.in);

  function toggle(id: string) {
    setOutgoingIds((current) => current.includes(id) ? current.filter((value) => value !== id) : [...current, id]);
    setReplacements((current) => Object.fromEntries(Object.entries(current).filter(([key]) => key !== id)));
  }

  return <form action={action} method="post" className="space-y-6">
    <input type="hidden" name="fingerprint" value={fingerprint} />
    <fieldset>
      <legend className="text-lg font-semibold text-slate-950">1. Vilka ska stå över?</legend>
      <p className="mt-1 text-sm text-slate-600">Välj en eller flera. Varje spelare som står över ersätts av en spelare du väljer i nästa steg.</p>
      <div className="mt-3 space-y-2">{outgoing.map((player) => <label key={player.id} className="flex min-h-12 cursor-pointer items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 has-[:checked]:border-blue-700 has-[:checked]:bg-blue-50">
        <input type="checkbox" name="outgoingPlayerId" value={player.id} checked={outgoingIds.includes(player.id)} onChange={() => toggle(player.id)} className="h-5 w-5" />
        <span className="min-w-0 flex-1 truncate font-medium text-slate-900">{player.name}</span><span className="text-xs text-slate-500">Nivå {player.level}</span>
      </label>)}</div>
    </fieldset>
    <fieldset>
      <legend className="text-lg font-semibold text-slate-950">2. Vem ersätter vem?</legend>
      {selectedOutgoing.length === 0 ? <p className="mt-2 text-sm text-slate-600">Välj först vilka som ska stå över.</p> : <div className="mt-3 space-y-3">{selectedOutgoing.map((player) => {
        const takenElsewhere = new Set(Object.entries(replacements).filter(([outId]) => outId !== player.id).map(([, inId]) => inId));
        return <div key={player.id} className="rounded-xl border border-slate-200 bg-white p-4">
          <label htmlFor={`incoming-${player.id}`} className="block text-sm font-medium text-slate-900">Ersättare för {player.name}</label>
          <select id={`incoming-${player.id}`} required name={`incoming:${player.id}`} value={replacements[player.id] ?? ""} onChange={(event) => setReplacements((current) => ({ ...current, [player.id]: event.target.value }))} className="mt-2 min-h-12 w-full rounded-lg border border-slate-300 bg-white px-3">
            <option value="">Välj spelare</option>
            {incoming.filter((candidate) => !takenElsewhere.has(candidate.id)).map((candidate) => <option key={candidate.id} value={candidate.id}>{candidate.name} (nivå {candidate.level})</option>)}
          </select>
        </div>;
      })}</div>}
    </fieldset>
    <section aria-live="polite" className="rounded-xl bg-slate-100 p-4">
      <h2 className="font-semibold text-slate-950">Kontrollera byten ({pairs.length})</h2>
      {pairs.length === 0 ? <p className="mt-2 text-sm text-slate-700">Inga byten valda.</p> : <ul className="mt-2 space-y-1 text-sm text-slate-700">{pairs.map((pair) => <li key={pair.out.id}>Ut: <strong>{pair.out.name}</strong> · In: <strong>{pair.in?.name ?? "Välj spelare"}</strong></li>)}</ul>}
    </section>
    <p id="adjust-hint" className="text-sm text-slate-600">{ready ? "Redo att bekräfta." : "Välj minst en spelare som ska stå över och en ersättare för varje."}</p>
    <button type="submit" aria-describedby="adjust-hint" disabled={!ready} className="min-h-12 w-full rounded-xl bg-blue-700 px-4 font-semibold text-white disabled:cursor-not-allowed disabled:bg-slate-300">{pairs.length > 1 ? `Bekräfta ${pairs.length} byten` : "Bekräfta byte"}</button>
  </form>;
}
