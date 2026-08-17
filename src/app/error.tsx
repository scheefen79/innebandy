"use client";

import { AppShell } from "@/components/app-shell";

type ErrorPageProps = {
  reset: () => void;
};

export default function ErrorPage({ reset }: ErrorPageProps) {
  return (
    <AppShell currentItem="Spelare">
      <section className="rounded-2xl bg-white px-5 py-10 text-center shadow-sm" role="alert">
        <h1 className="text-xl font-semibold text-slate-950">Spelarna kunde inte hämtas</h1>
        <p className="mx-auto mt-2 max-w-sm text-sm leading-6 text-slate-600">
          Försök igen. Om problemet kvarstår kan du kontrollera anslutningen senare.
        </p>
        <button
          className="mt-5 min-h-11 rounded-xl bg-[#082B4C] px-5 text-sm font-semibold text-white hover:bg-[#0B3B68] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#082B4C]"
          onClick={reset}
          type="button"
        >
          Försök igen
        </button>
      </section>
    </AppShell>
  );
}
