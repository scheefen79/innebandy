import { AppShell } from "@/components/app-shell";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export const dynamic = "force-dynamic";

export default async function Home() {
  const supabase = await createClient();
  const { data: verifiedSession } = await supabase.auth.getClaims();
  const claims = verifiedSession?.claims;

  if (!claims?.sub) {
    redirect("/login");
  }

  const { data: membership, error } = await supabase
    .from("team_members")
    .select("team_id")
    .eq("is_active", true)
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new Error("Det gick inte att verifiera lagbehörigheten.");
  }

  if (!membership) {
    redirect("/access-denied");
  }

  return (
    <AppShell>
      <section className="space-y-6">
        <header>
          <p className="text-sm font-medium text-slate-500">Skyddad tränaryta</p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-slate-950">
            Översikt
          </h1>
        </header>

        <article className="rounded-2xl bg-[#082B4C] p-5 text-white shadow-sm">
          <p className="text-sm font-medium text-blue-100">Säker session aktiv</p>
          <h2 className="mt-2 text-xl font-semibold">Nästa steg: säker spelarlista</h2>
          <p className="mt-2 max-w-xl text-sm leading-6 text-blue-100">
            Du är inloggad och ditt aktiva lagmedlemskap är verifierat. Den läsbara
            spelarlistan byggs i nästa steg.
          </p>
        </article>

        <section aria-labelledby="foundation-heading">
          <h2 id="foundation-heading" className="text-lg font-semibold text-slate-950">
            Skelettet innehåller
          </h2>
          <ul className="mt-3 divide-y divide-slate-200 rounded-2xl bg-white px-4 text-sm text-slate-700 shadow-sm">
            <li className="py-4">Cookie-baserad Supabase-session</li>
            <li className="py-4">Verifierad inloggning och lagbehörighet</li>
            <li className="py-4">Utloggning på mobil och desktop</li>
          </ul>
        </section>
      </section>
    </AppShell>
  );
}
