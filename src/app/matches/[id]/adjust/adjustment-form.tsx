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
  const [outgoingId, setOutgoingId] = useState("");
  const [incomingId, setIncomingId] = useState("");
  const outgoingName = outgoing.find((player) => player.id === outgoingId)?.name;
  const incomingName = incoming.find((player) => player.id === incomingId)?.name;
  const ready = Boolean(outgoingName && incomingName);

  return <form action={action} method="post" className="space-y-6">
    <input type="hidden" name="fingerprint" value={fingerprint} />
    <fieldset>
      <legend className="text-lg font-semibold text-slate-950">1. Vem ska stå över?</legend>
      <div className="mt-3 space-y-2">{outgoing.map((player) => <label key={player.id} className="flex min-h-12 cursor-pointer items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 has-[:checked]:border-blue-700 has-[:checked]:bg-blue-50">
        <input required type="radio" name="outgoingPlayerId" value={player.id} checked={outgoingId === player.id} onChange={() => setOutgoingId(player.id)} className="h-5 w-5" />
        <span className="min-w-0 flex-1 truncate font-medium text-slate-900">{player.name}</span><span className="text-xs text-slate-500">Nivå {player.level}</span>
      </label>)}</div>
    </fieldset>
    <fieldset>
      <legend className="text-lg font-semibold text-slate-950">2. Vem ska läggas till?</legend>
      <div className="mt-3 space-y-2">{incoming.map((player) => <label key={player.id} className="flex min-h-12 cursor-pointer items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 has-[:checked]:border-blue-700 has-[:checked]:bg-blue-50">
        <input required type="radio" name="incomingPlayerId" value={player.id} checked={incomingId === player.id} onChange={() => setIncomingId(player.id)} className="h-5 w-5" />
        <span className="min-w-0 flex-1 truncate font-medium text-slate-900">{player.name}</span><span className="text-xs text-slate-500">Nivå {player.level}</span>
      </label>)}</div>
    </fieldset>
    <section aria-live="polite" className="rounded-xl bg-slate-100 p-4">
      <h2 className="font-semibold text-slate-950">Kontrollera bytet</h2>
      <p className="mt-2 text-sm text-slate-700">Ut: <strong>{outgoingName ?? "Välj spelare"}</strong></p>
      <p className="mt-1 text-sm text-slate-700">In: <strong>{incomingName ?? "Välj spelare"}</strong></p>
    </section>
    <button type="submit" disabled={!ready} className="min-h-12 w-full rounded-xl bg-blue-700 px-4 font-semibold text-white disabled:cursor-not-allowed disabled:bg-slate-300">Bekräfta byte</button>
  </form>;
}
