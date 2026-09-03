export const dynamic = "force-dynamic";

export default function AccessDeniedPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-[#F5F7FA] px-4 py-10">
      <section className="w-full max-w-md rounded-2xl bg-white p-6 text-center shadow-sm sm:p-8">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-orange-700">
          Åtkomst saknas
        </p>
        <h1 className="mt-3 text-2xl font-semibold tracking-tight text-slate-950">
          Sidan är inte tillgänglig för kontot
        </h1>
        <p className="mt-3 text-sm leading-6 text-slate-600">
          Kontot saknar antingen ett aktivt lagmedlemskap eller den roll som krävs för den här sidan. Be
          projektägaren kontrollera medlemskapet och rollen om du tror att detta är fel.
        </p>
        <form action="/auth/logout" className="mt-6" method="post">
          <button
            className="min-h-12 w-full rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm font-semibold text-slate-800 hover:bg-slate-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600"
            type="submit"
          >
            Logga ut
          </button>
        </form>
      </section>
    </main>
  );
}
