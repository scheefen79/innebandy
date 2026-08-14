type LoginFormProps = {
  errorMessage: string | null;
  nextPath: string;
};

export function LoginForm({ errorMessage, nextPath }: LoginFormProps) {
  return (
    <form action="/auth/login" className="mt-8 space-y-5" method="post">
      <input name="next" type="hidden" value={nextPath} />

      <div>
        <label className="text-sm font-medium text-slate-800" htmlFor="email">
          E-postadress
        </label>
        <input
          autoComplete="email"
          autoFocus
          className="mt-2 min-h-12 w-full rounded-xl border border-slate-300 bg-white px-4 text-base text-slate-950 outline-none transition focus:border-blue-600 focus:ring-2 focus:ring-blue-100"
          id="email"
          name="email"
          required
          type="email"
        />
      </div>

      <div>
        <label className="text-sm font-medium text-slate-800" htmlFor="password">
          Lösenord
        </label>
        <input
          autoComplete="current-password"
          className="mt-2 min-h-12 w-full rounded-xl border border-slate-300 bg-white px-4 text-base text-slate-950 outline-none transition focus:border-blue-600 focus:ring-2 focus:ring-blue-100"
          id="password"
          minLength={6}
          name="password"
          required
          type="password"
        />
      </div>

      {errorMessage ? (
        <p
          aria-live="polite"
          className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800"
          role="alert"
        >
          {errorMessage}
        </p>
      ) : null}

      <button
        className="min-h-12 w-full rounded-xl bg-[#1677FF] px-4 py-3 text-sm font-semibold text-white transition hover:bg-blue-700 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600"
        type="submit"
      >
        Logga in
      </button>
    </form>
  );
}
