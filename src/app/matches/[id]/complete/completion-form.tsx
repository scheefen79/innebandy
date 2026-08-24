"use client";

import { useMemo, useState } from "react";
import { defaultPlayedPlayerIds, summarizeParticipation, type CompletionParticipant } from "@/features/selections/match-completion";

export function CompletionForm({ action, fingerprint, participants }: { action: string; fingerprint: string; participants: CompletionParticipant[] }) {
  const [playedIds, setPlayedIds] = useState(() => new Set(defaultPlayedPlayerIds(participants)));
  const summary = useMemo(() => summarizeParticipation(participants, playedIds), [participants, playedIds]);
  const toggle = (playerId: string) => setPlayedIds((current) => {
    const next = new Set(current);
    if (next.has(playerId)) next.delete(playerId); else next.add(playerId);
    return next;
  });

  return <form action={action} method="post" className="space-y-6">
    <input type="hidden" name="fingerprint" value={fingerprint} />
    {participants.map((participant) => <input key={participant.playerId} type="hidden" name="playerId" value={participant.playerId} />)}
    {(["regular", "extra"] as const).map((type) => {
      const group = participants.filter((participant) => participant.selectionType === type);
      if (group.length === 0) return null;
      return <fieldset key={type}><legend className="text-lg font-semibold text-slate-950">{type === "regular" ? "Ordinarie" : "Extra inhoppare"}</legend>
        <div className="mt-3 space-y-2">{group.map((participant) => <label key={participant.playerId} className="flex min-h-14 cursor-pointer items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 has-[:checked]:border-blue-700 has-[:checked]:bg-blue-50">
          <input type="checkbox" name="playedPlayerId" value={participant.playerId} checked={playedIds.has(participant.playerId)} onChange={() => toggle(participant.playerId)} className="h-5 w-5" />
          <span className="min-w-0 flex-1 truncate font-medium text-slate-900">{participant.name}</span><span className="shrink-0 text-sm font-semibold text-slate-700">Spelade</span>
        </label>)}</div>
      </fieldset>;
    })}
    <section aria-live="polite" className="rounded-xl bg-slate-100 p-4"><h2 className="font-semibold text-slate-950">Sammanfattning</h2>
      <dl className="mt-3 grid grid-cols-2 gap-3 text-sm"><div><dt className="text-slate-600">Ordinarie spelade</dt><dd className="font-semibold text-slate-950">{summary.regularPlayed}</dd></div><div><dt className="text-slate-600">Ordinarie frånvarande</dt><dd className="font-semibold text-slate-950">{summary.regularAbsent}</dd></div><div><dt className="text-slate-600">Extra inhopp</dt><dd className="font-semibold text-slate-950">{summary.extraPlayed}</dd></div><div><dt className="text-slate-600">Extra frånvarande</dt><dd className="font-semibold text-slate-950">{summary.extraAbsent}</dd></div></dl>
    </section>
    <div className="rounded-xl border border-amber-300 bg-amber-50 p-4 text-sm text-amber-950"><strong>Kontrollera innan du sparar.</strong> Matchen låses som genomförd och deltagandet kan inte ändras i den här versionen.</div>
    <button type="submit" className="min-h-12 w-full rounded-xl bg-blue-700 px-4 font-semibold text-white">Genomför match</button>
  </form>;
}
