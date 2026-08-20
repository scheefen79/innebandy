import { AppShell } from "@/components/app-shell";

export default function MatchesLoading() {
  return <AppShell currentItem="Matcher"><div aria-busy="true" aria-live="polite" className="mx-auto max-w-3xl"><span className="sr-only">Laddar matcher</span><div className="h-9 w-40 animate-pulse rounded bg-slate-200" /><div className="mt-8 space-y-3">{[1, 2, 3].map((item) => <div key={item} className="h-28 animate-pulse rounded-2xl bg-slate-200" />)}</div></div></AppShell>;
}
