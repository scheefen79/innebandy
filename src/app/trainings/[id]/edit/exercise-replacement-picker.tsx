"use client";

import Image from "next/image";
import { useState } from "react";
import { additionCandidates, candidateAreaText, replacementCandidates, type ExerciseCatalogItem } from "@/features/trainings/exercise-catalog";
import type { TrainingItem, TrainingSection } from "@/features/trainings/training-plans";

function Preview({ exercise }: { exercise: ExerciseCatalogItem }) {
  const [imageUnavailable, setImageUnavailable] = useState(false);
  const [videoUnavailable, setVideoUnavailable] = useState(false);
  return <section aria-label={`Förhandsgranskning: ${exercise.title}`} className="mt-4 overflow-hidden rounded-xl border border-slate-200 bg-slate-50">
    {exercise.sourceVideoUrl && !videoUnavailable ? <div className="bg-slate-950"><video controls playsInline preload="metadata" poster={exercise.sourceImageUrl ?? undefined} className="aspect-video w-full" onError={() => setVideoUnavailable(true)}><source src={exercise.sourceVideoUrl} type="video/mp4" />Din webbläsare kan inte visa videon.</video></div> : null}
    {exercise.sourceImageUrl && !imageUnavailable && (!exercise.sourceVideoUrl || videoUnavailable) ? <Image src={exercise.sourceImageUrl} alt={`Övningsbild: ${exercise.title}`} width={960} height={540} className="aspect-video w-full object-contain" onError={() => setImageUnavailable(true)} /> : null}
    <div className="p-4">
      {videoUnavailable ? <p role="status" className="text-sm text-slate-700">Videon kunde inte laddas. Originalövningen kan fortfarande öppnas nedan.</p> : null}
      {!exercise.sourceVideoUrl ? <p className="text-sm text-slate-700">Ingen verifierad video är tillgänglig för denna övning.</p> : null}
      {!exercise.sourceImageUrl || imageUnavailable ? <p className="mt-2 text-sm text-slate-700">Ingen originalbild är tillgänglig.</p> : null}
      {exercise.summary ? <p className="mt-3 text-sm leading-6 text-slate-700">{exercise.summary}</p> : <p className="mt-3 text-sm text-slate-700">Läs den fullständiga beskrivningen hos Svensk Innebandy innan du ersätter momentet.</p>}
      <p className="mt-3 text-xs font-semibold text-slate-600">Tema: {exercise.themes.join(" · ")}</p>
      <p className="mt-1 text-xs text-slate-600">Färdigheter: {exercise.skills.join(" · ") || "Ej angivet"}</p>
      <a href={exercise.sourceUrl} target="_blank" rel="noreferrer" className="mt-3 inline-flex min-h-11 items-center text-sm font-semibold text-blue-700 underline">Läs originalövningen hos Svensk Innebandy</a>
    </div>
  </section>;
}

export function ExerciseReplacementPicker({ item, themeBlock, onReplace }: { item: TrainingItem; themeBlock: number; onReplace: (exercise: ExerciseCatalogItem) => void }) {
  const [open, setOpen] = useState(false);
  const [selected, setSelected] = useState<ExerciseCatalogItem | null>(null);
  const [sourceReviewed, setSourceReviewed] = useState(false);
  const candidates = replacementCandidates({ item, themeBlock });
  const close = () => { setOpen(false); setSelected(null); setSourceReviewed(false); };
  const confirm = () => { if (!selected) return; onReplace(selected); close(); };
  const selectCandidate = (candidate: ExerciseCatalogItem) => { setSelected(current => current?.id === candidate.id ? null : candidate); setSourceReviewed(false); };
  return <>
    <button type="button" onClick={() => setOpen(true)} className="mt-3 min-h-11 rounded-lg border border-blue-700 px-3 text-sm font-semibold text-blue-700">Byt övning</button>
    {open ? <div role="dialog" aria-modal="true" aria-label={`Byt övning: ${item.title}`} className="fixed inset-0 z-50 overflow-y-auto bg-slate-950/60 p-4 sm:p-8">
      <div className="mx-auto max-w-2xl rounded-2xl bg-white p-5 shadow-xl sm:p-6">
        <div className="flex items-start justify-between gap-4"><div><h2 className="text-xl font-bold text-slate-950">Byt övning</h2><p className="mt-1 text-sm text-slate-600">Alternativ för block {themeBlock} · {candidateAreaText(item, themeBlock) || "samma träningsområde"}</p></div><button type="button" onClick={close} className="min-h-11 px-2 text-sm font-semibold text-slate-700" aria-label="Stäng ersättningsvyn">Stäng</button></div>
        {candidates.length === 0 ? <div className="mt-5 rounded-xl bg-slate-50 p-4"><h3 className="font-semibold text-slate-950">Inga verifierade alternativ ännu</h3><p className="mt-1 text-sm text-slate-600">Behåll övningen eller redigera momentet manuellt. Vi visar inte förslag från fel block eller område.</p></div> : <ul className="mt-5 space-y-3">{candidates.map(candidate => <li key={candidate.id} className="rounded-xl border border-slate-200 p-4"><div className="flex flex-wrap items-start justify-between gap-3"><div><h3 className="font-semibold text-slate-950">{candidate.title}</h3><p className="mt-1 text-xs font-semibold text-blue-800">{candidate.themes.join(" · ")}</p></div><button type="button" onClick={() => selectCandidate(candidate)} className="min-h-11 rounded-lg border border-blue-700 px-3 text-sm font-semibold text-blue-700">{selected?.id === candidate.id ? "Dölj" : "Visa övning"}</button></div>{selected?.id === candidate.id ? <Preview exercise={candidate} /> : null}</li>)}</ul>}
        {selected ? <label className="mt-5 flex items-start gap-3 rounded-xl bg-blue-50 p-3 text-sm text-slate-800"><input type="checkbox" checked={sourceReviewed} onChange={event => setSourceReviewed(event.target.checked)} className="mt-1 size-4" /><span>Jag har granskat originalövningen, inklusive genomförande och coachingpunkter, innan jag byter.</span></label> : null}
        <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end"><button type="button" onClick={close} className="min-h-11 rounded-lg border border-slate-300 px-4 font-semibold text-slate-700">Avbryt</button><button type="button" disabled={!selected || !sourceReviewed} onClick={confirm} className="min-h-11 rounded-lg bg-blue-700 px-4 font-semibold text-white disabled:cursor-not-allowed disabled:bg-slate-300">Ersätt med denna övning</button></div>
        {selected ? <p className="mt-3 text-xs text-slate-600">Ersätter endast detta moment i detta träningspass. Spara planeringen för att bekräfta ändringen.</p> : null}
      </div>
    </div> : null}
  </>;
}

export function ExerciseAdditionPicker({ themeBlock, onAdd, onCreateManual }: { themeBlock: number; onAdd: (exercise: ExerciseCatalogItem, section: TrainingSection) => void; onCreateManual: () => void }) {
  const [open, setOpen] = useState(false);
  const [section, setSection] = useState<TrainingSection>("match_exercise");
  const [selected, setSelected] = useState<ExerciseCatalogItem | null>(null);
  const [sourceReviewed, setSourceReviewed] = useState(false);
  const candidates = additionCandidates({ themeBlock, section });
  const close = () => { setOpen(false); setSelected(null); setSourceReviewed(false); };
  const selectCandidate = (candidate: ExerciseCatalogItem) => { setSelected(current => current?.id === candidate.id ? null : candidate); setSourceReviewed(false); };
  return <>
    <button type="button" onClick={() => setOpen(true)} className="mt-4 min-h-11 rounded-xl border border-blue-700 px-4 font-semibold text-blue-700">Lägg till övning</button>
    {open ? <div role="dialog" aria-modal="true" aria-label="Lägg till övning" className="fixed inset-0 z-50 overflow-y-auto bg-slate-950/60 p-4 sm:p-8">
      <div className="mx-auto max-w-2xl rounded-2xl bg-white p-5 shadow-xl sm:p-6">
        <div className="flex items-start justify-between gap-4"><div><h2 className="text-xl font-bold text-slate-950">Lägg till övning</h2><p className="mt-1 text-sm text-slate-600">Välj en verifierad övning för block {themeBlock}, eller skapa ett eget moment.</p></div><button type="button" onClick={close} className="min-h-11 px-2 text-sm font-semibold text-slate-700">Stäng</button></div>
        <div className="mt-5 flex gap-2"><button type="button" onClick={() => { setSection("technique"); setSelected(null); setSourceReviewed(false); }} className={`min-h-11 rounded-lg px-3 text-sm font-semibold ${section === "technique" ? "bg-blue-700 text-white" : "border border-slate-300 text-slate-700"}`}>Teknikövning</button><button type="button" onClick={() => { setSection("match_exercise"); setSelected(null); setSourceReviewed(false); }} className={`min-h-11 rounded-lg px-3 text-sm font-semibold ${section === "match_exercise" ? "bg-emerald-700 text-white" : "border border-slate-300 text-slate-700"}`}>Matchövning</button></div>
        <ul className="mt-5 space-y-3">{candidates.map(candidate => <li key={candidate.id} className="rounded-xl border border-slate-200 p-4"><div className="flex flex-wrap items-start justify-between gap-3"><div><h3 className="font-semibold text-slate-950">{candidate.title}</h3><p className="mt-1 text-xs font-semibold text-blue-800">{candidate.themes.join(" · ")}</p></div><button type="button" onClick={() => selectCandidate(candidate)} className="min-h-11 rounded-lg border border-blue-700 px-3 text-sm font-semibold text-blue-700">{selected?.id === candidate.id ? "Dölj" : "Visa övning"}</button></div>{selected?.id === candidate.id ? <Preview exercise={candidate} /> : null}</li>)}</ul>
        {selected ? <label className="mt-5 flex items-start gap-3 rounded-xl bg-blue-50 p-3 text-sm text-slate-800"><input type="checkbox" checked={sourceReviewed} onChange={event => setSourceReviewed(event.target.checked)} className="mt-1 size-4" /><span>Jag har granskat originalövningen innan jag lägger till den.</span></label> : null}
        <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:justify-between"><button type="button" onClick={() => { onCreateManual(); close(); }} className="min-h-11 rounded-lg border border-slate-300 px-4 font-semibold text-slate-700">Skapa egen övning</button><div className="flex flex-col-reverse gap-3 sm:flex-row"><button type="button" onClick={close} className="min-h-11 rounded-lg border border-slate-300 px-4 font-semibold text-slate-700">Avbryt</button><button type="button" disabled={!selected || !sourceReviewed} onClick={() => { if (selected) onAdd(selected, section); close(); }} className="min-h-11 rounded-lg bg-blue-700 px-4 font-semibold text-white disabled:cursor-not-allowed disabled:bg-slate-300">Lägg till vald övning</button></div></div>
      </div>
    </div> : null}
  </>;
}
