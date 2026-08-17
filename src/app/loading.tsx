import { AppShell } from "@/components/app-shell";

export default function Loading() {
  return (
    <AppShell currentItem="Spelare">
      <section aria-busy="true" aria-labelledby="players-loading-heading" className="space-y-5">
        <header>
          <p className="text-sm font-medium text-slate-500">Laddar säsong…</p>
          <h1 id="players-loading-heading" className="mt-1 text-2xl font-semibold text-slate-950">
            Spelare
          </h1>
        </header>
        <span className="sr-only">Laddar spelare</span>
        <ul aria-hidden="true" className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {[1, 2, 3, 4, 5, 6].map((item) => (
            <li key={item} className="h-[58px] animate-pulse rounded-2xl bg-slate-200" />
          ))}
        </ul>
      </section>
    </AppShell>
  );
}
