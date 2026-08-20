"use client";

import { AppShell } from "@/components/app-shell";

export default function MatchesError({ reset }: { reset: () => void }) {
  return <AppShell currentItem="Matcher"><div role="alert" className="mx-auto max-w-xl rounded-2xl border border-red-200 bg-white p-6"><h1 className="text-xl font-bold text-slate-950">Matcher kunde inte visas</h1><p className="mt-2 text-sm text-slate-600">Försök igen. Om felet kvarstår kan du gå tillbaka till spelarlistan.</p><button onClick={reset} className="mt-5 min-h-11 rounded-xl bg-blue-700 px-4 text-sm font-semibold text-white">Försök igen</button></div></AppShell>;
}
