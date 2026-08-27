"use client";

import { AppShell } from "@/components/app-shell";
import Link from "next/link";

type ErrorPageProps = {
  reset: () => void;
};

export default function ErrorPage({ reset }: ErrorPageProps) {
  return (
    <AppShell currentItem="Kommande">
      <section className="rounded-2xl bg-white px-5 py-10 text-center shadow-sm" role="alert">
        <h1 className="text-xl font-semibold text-slate-950">Sidan kunde inte hämtas</h1>
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
        <div className="mt-4 flex justify-center gap-4 text-sm font-semibold"><Link className="text-blue-700 underline" href="/matches">Matcher</Link><Link className="text-blue-700 underline" href="/players">Spelare</Link></div>
      </section>
    </AppShell>
  );
}
