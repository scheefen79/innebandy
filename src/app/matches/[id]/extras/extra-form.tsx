"use client";

import { useState } from "react";
import type { ExtraSubstituteCandidate } from "@/features/selections/extra-substitute";

export function ExtraForm({ action, candidates, fingerprint }: {
  action: string;
  candidates: ExtraSubstituteCandidate[];
  fingerprint: string;
}) {
  const [playerId, setPlayerId] = useState("");
  const selected = candidates.find((candidate) => candidate.id === playerId);
  return <form action={action} method="post" className="space-y-6">
    <input type="hidden" name="fingerprint" value={fingerprint} />
    <fieldset>
      <legend className="text-lg font-semibold text-slate-950">Välj extra inhoppare</legend>
      <p className="mt-1 text-sm text-slate-600">Rekommendationen prioriterar lägst antal extra inhopp och därefter lägst antal ordinarie matcher.</p>
      <div className="mt-4 space-y-2">{candidates.map((candidate) => <label key={candidate.id} className="flex min-h-14 cursor-pointer items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 has-[:checked]:border-blue-700 has-[:checked]:bg-blue-50">
        <input required type="radio" name="playerId" value={candidate.id} checked={playerId === candidate.id} onChange={() => setPlayerId(candidate.id)} className="h-5 w-5" />
        <span className="min-w-0 flex-1"><span className="block truncate font-medium text-slate-900">{candidate.name}</span><span className="mt-1 block text-xs text-slate-600">Ordinarie matcher: {candidate.regularCount} · Extra inhopp: {candidate.completedExtraCount}</span></span>
        {candidate.recommended ? <span className="shrink-0 rounded-full bg-emerald-50 px-2 py-1 text-xs font-semibold text-emerald-800">Rekommenderad</span> : null}
      </label>)}</div>
    </fieldset>
    <section aria-live="polite" className="rounded-xl bg-slate-100 p-4">
      <h2 className="font-semibold text-slate-950">Kontrollera valet</h2>
      <p className="mt-2 text-sm text-slate-700">Extra inhoppare: <strong>{selected?.name ?? "Välj spelare"}</strong></p>
    </section>
    <button type="submit" disabled={!selected} className="min-h-12 w-full rounded-xl bg-blue-700 px-4 font-semibold text-white disabled:cursor-not-allowed disabled:bg-slate-300">Lägg till extra inhoppare</button>
  </form>;
}
