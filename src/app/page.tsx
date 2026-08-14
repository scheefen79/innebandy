import { AppShell } from "@/components/app-shell";

export default function Home() {
  return (
    <AppShell>
      <section className="space-y-6">
        <header>
          <p className="text-sm font-medium text-slate-500">Implementation 01</p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-slate-950">
            Översikt
          </h1>
        </header>

        <article className="rounded-2xl bg-[#082B4C] p-5 text-white shadow-sm">
          <p className="text-sm font-medium text-blue-100">Applikationsgrund klar</p>
          <h2 className="mt-2 text-xl font-semibold">Nästa steg: säker spelarlista</h2>
          <p className="mt-2 max-w-xl text-sm leading-6 text-blue-100">
            Inloggning, lagbehörighet och aktiva spelare byggs i nästa del av
            implementationen. Inga match- eller spelardata visas ännu.
          </p>
        </article>

        <section aria-labelledby="foundation-heading">
          <h2 id="foundation-heading" className="text-lg font-semibold text-slate-950">
            Skelettet innehåller
          </h2>
          <ul className="mt-3 divide-y divide-slate-200 rounded-2xl bg-white px-4 text-sm text-slate-700 shadow-sm">
            <li className="py-4">Mobile-first AppShell</li>
            <li className="py-4">TypeScript, lint, test och produktionsbygge</li>
            <li className="py-4">Separat domänlager för kommande affärslogik</li>
          </ul>
        </section>
      </section>
    </AppShell>
  );
}
