import { LoginForm } from "@/app/login/login-form";
import { getSafeNextPath } from "@/lib/auth/safe-next-path";

type LoginPageProps = {
  searchParams: Promise<{ error?: string | string[]; next?: string | string[] }>;
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const parameters = await searchParams;
  const nextPath = getSafeNextPath(
    Array.isArray(parameters.next) ? parameters.next[0] : parameters.next,
  );
  const hasLoginError =
    (Array.isArray(parameters.error) ? parameters.error[0] : parameters.error) ===
    "invalid";

  return (
    <main className="flex min-h-screen items-center justify-center bg-[#F5F7FA] px-4 py-10">
      <section className="w-full max-w-md rounded-2xl bg-white p-6 shadow-sm sm:p-8">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-blue-700">
          FBC Sollentuna P17
        </p>
        <h1 className="mt-3 text-2xl font-semibold tracking-tight text-slate-950">
          Logga in som tränare
        </h1>
        <p className="mt-2 text-sm leading-6 text-slate-600">
          Använd det tränarkonto som har kopplats till laget.
        </p>
        <LoginForm
          errorMessage={
            hasLoginError
              ? "Inloggningen misslyckades. Kontrollera dina uppgifter."
              : null
          }
          nextPath={nextPath}
        />
      </section>
    </main>
  );
}
