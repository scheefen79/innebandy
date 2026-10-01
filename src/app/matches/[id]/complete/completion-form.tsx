"use client";

import { useMemo, useState } from "react";
import { defaultPlayedPlayerIds, summarizeParticipation, type CompletionExtraCandidate, type CompletionParticipant } from "@/features/selections/match-completion";

export function CompletionForm({ action, fingerprint, participants, extraCandidates }: { action: string; fingerprint: string; participants: CompletionParticipant[]; extraCandidates: CompletionExtraCandidate[] }) {
  const [playedIds, setPlayedIds] = useState(() => new Set(defaultPlayedPlayerIds(participants)));
  const [addedExtraIds, setAddedExtraIds] = useState(() => new Set<string>());
  const summary = useMemo(() => {
    const addedExtras = extraCandidates
      .filter((candidate) => addedExtraIds.has(candidate.playerId))
      .map((candidate) => ({ ...candidate, selectionType: "extra" as const, played: true }));
    return summarizeParticipation([...participants, ...addedExtras], [...playedIds, ...addedExtraIds]);
  }, [participants, extraCandidates, playedIds, addedExtraIds]);
  const toggle = (playerId: string) => setPlayedIds((current) => {
    const next = new Set(current);
    if (next.has(playerId)) next.delete(playerId); else next.add(playerId);
    return next;
  });
  const toggleExtra = (playerId: string) => setAddedExtraIds((current) => {
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
    <fieldset><legend className="text-lg font-semibold text-slate-950">Lägg till extra spelare som deltog</legend>
      <p className="mt-1 text-sm text-slate-600">Välj en eller flera spelare som hoppade in utan att vara registrerade före matchen.</p>
      {extraCandidates.length === 0 ? <p className="mt-3 rounded-xl bg-slate-50 p-4 text-sm text-slate-600">Det finns inga fler aktiva spelare att lägga till.</p> : <div className="mt-3 space-y-2">{extraCandidates.map((candidate) => <label key={candidate.playerId} className="flex min-h-14 cursor-pointer items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 py-3 has-[:checked]:border-violet-700 has-[:checked]:bg-violet-50">
        <input type="checkbox" name="extraPlayerId" value={candidate.playerId} checked={addedExtraIds.has(candidate.playerId)} onChange={() => toggleExtra(candidate.playerId)} className="h-5 w-5" />
        <span className="min-w-0 flex-1 truncate font-medium text-slate-900">{candidate.name}</span><span className="shrink-0 text-sm font-semibold text-slate-700">Extra</span>
      </label>)}</div>}
    </fieldset>
    <section aria-live="polite" className="rounded-xl bg-slate-100 p-4"><h2 className="font-semibold text-slate-950">Sammanfattning</h2>
      <dl className="mt-3 grid grid-cols-2 gap-3 text-sm"><div><dt className="text-slate-600">Ordinarie spelade</dt><dd className="font-semibold text-slate-950">{summary.regularPlayed}</dd></div><div><dt className="text-slate-600">Ordinarie frånvarande</dt><dd className="font-semibold text-slate-950">{summary.regularAbsent}</dd></div><div><dt className="text-slate-600">Extra inhopp</dt><dd className="font-semibold text-slate-950">{summary.extraPlayed}</dd></div><div><dt className="text-slate-600">Extra frånvarande</dt><dd className="font-semibold text-slate-950">{summary.extraAbsent}</dd></div></dl>
    </section>
    <div className="rounded-xl border border-amber-300 bg-amber-50 p-4 text-sm text-amber-950"><strong>Kontrollera innan du sparar.</strong> Matchen låses som genomförd och deltagandet kan inte ändras efteråt.</div>
    <button type="submit" className="min-h-12 w-full rounded-xl bg-blue-700 px-4 font-semibold text-white">Genomför match</button>
  </form>;
}
