import { AppShell } from "@/components/app-shell";

export default function Loading() {
  return (
    <AppShell currentItem="Översikt">
      <section aria-busy="true" aria-labelledby="overview-loading-heading" className="mx-auto max-w-4xl space-y-5">
        <header>
          <p className="text-sm font-medium text-slate-500">Laddar säsong…</p>
          <h1 id="overview-loading-heading" className="mt-1 text-2xl font-semibold text-slate-950">
            Översikt
          </h1>
        </header>
        <span className="sr-only">Laddar översikt</span>
        <ul aria-hidden="true" className="grid gap-5 lg:grid-cols-2">
          {[1, 2, 3].map((item) => (
            <li key={item} className="h-40 animate-pulse rounded-2xl bg-slate-200" />
          ))}
        </ul>
      </section>
    </AppShell>
  );
}
