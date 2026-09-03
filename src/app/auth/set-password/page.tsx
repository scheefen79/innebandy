"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type Status = "loading" | "ready" | "saving" | "invalid";

export default function SetPasswordPage() {
  const router = useRouter();
  const [status, setStatus] = useState<Status>("loading");
  const [password, setPassword] = useState("");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function establishSessionFromLink() {
      const supabase = createClient();
      const hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ""));
      const accessToken = hashParams.get("access_token");
      const refreshToken = hashParams.get("refresh_token");
      const queryCode = new URLSearchParams(window.location.search).get("code");

      let established = false;
      if (accessToken && refreshToken) {
        const { error } = await supabase.auth.setSession({ access_token: accessToken, refresh_token: refreshToken });
        established = !error;
      } else if (queryCode) {
        const { error } = await supabase.auth.exchangeCodeForSession(queryCode);
        established = !error;
      }

      // Remove the tokens from the address bar regardless of outcome so they never linger in
      // browser history or get shared accidentally.
      window.history.replaceState(null, "", window.location.pathname);

      if (!cancelled) setStatus(established ? "ready" : "invalid");
    }

    void establishSessionFromLink();
    return () => {
      cancelled = true;
    };
  }, []);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    if (password.length < 6) {
      setErrorMessage("Lösenordet måste vara minst 6 tecken.");
      return;
    }
    setStatus("saving");
    setErrorMessage(null);
    const supabase = createClient();
    const { error } = await supabase.auth.updateUser({ password });
    if (error) {
      setErrorMessage("Lösenordet kunde inte sparas. Försök igen.");
      setStatus("ready");
      return;
    }
    router.replace("/");
    router.refresh();
  }

  if (status === "loading") {
    return (
      <main className="flex min-h-screen items-center justify-center bg-[#F5F7FA] px-4 py-10">
        <p className="text-sm text-slate-600">Verifierar länken…</p>
      </main>
    );
  }

  if (status === "invalid") {
    return (
      <main className="flex min-h-screen items-center justify-center bg-[#F5F7FA] px-4 py-10">
        <section className="w-full max-w-md rounded-2xl bg-white p-6 text-center shadow-sm sm:p-8">
          <p className="text-xs font-semibold uppercase tracking-[0.16em] text-orange-700">Länken fungerar inte</p>
          <h1 className="mt-3 text-2xl font-semibold tracking-tight text-slate-950">Länken är ogiltig eller har redan använts</h1>
          <p className="mt-3 text-sm leading-6 text-slate-600">
            Be den som bjöd in dig att skicka en ny inbjudan, eller be projektägaren om en ny lösenordsåterställning.
          </p>
        </section>
      </main>
    );
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-[#F5F7FA] px-4 py-10">
      <section className="w-full max-w-md rounded-2xl bg-white p-6 shadow-sm sm:p-8">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-blue-700">FBC Sollentuna P17</p>
        <h1 className="mt-3 text-2xl font-semibold tracking-tight text-slate-950">Sätt ditt lösenord</h1>
        <p className="mt-3 text-sm leading-6 text-slate-600">Detta blir lösenordet du loggar in med framöver.</p>
        <form onSubmit={handleSubmit} className="mt-6 space-y-5">
          <div>
            <label htmlFor="password" className="text-sm font-medium text-slate-800">
              Nytt lösenord
            </label>
            <input
              id="password"
              name="password"
              type="password"
              minLength={6}
              required
              autoComplete="new-password"
              autoFocus
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="mt-2 min-h-12 w-full rounded-xl border border-slate-300 bg-white px-4 text-base text-slate-950 outline-none transition focus:border-blue-600 focus:ring-2 focus:ring-blue-100"
            />
          </div>
          {errorMessage ? (
            <p role="alert" className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
              {errorMessage}
            </p>
          ) : null}
          <button
            type="submit"
            disabled={status === "saving"}
            className="min-h-12 w-full rounded-xl bg-[#1677FF] px-4 py-3 text-sm font-semibold text-white transition hover:bg-blue-700 disabled:opacity-60"
          >
            {status === "saving" ? "Sparar…" : "Spara lösenord"}
          </button>
        </form>
      </section>
    </main>
  );
}
