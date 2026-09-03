import type { TeamMemberListItem } from "./team-member-list";

const roleLabels: Record<string, string> = { coach: "Tränare", viewer: "Besökare" };

const inviteErrorText: Record<string, string> = {
  invalid: "Ange en giltig e-postadress och välj en roll.",
  already_active: "Den e-postadressen är redan en aktiv medlem i laget.",
  already_inactive: "Den e-postadressen finns redan i laget men är inaktiverad. Återaktivera personen nedan istället för att bjuda in på nytt.",
  unlinked_account: "Det finns redan ett konto med den e-postadressen, men det är inte kopplat till laget. Kontakta appens ägare.",
  send_failed: "Inbjudan kunde inte skickas. Försök igen om en stund.",
};

const mutationErrorText: Record<string, string> = {
  stale: "Medlemmen ändrades av någon annan precis innan. Ladda om sidan och försök igen.",
  last_active_coach: "Det här är lagets sista aktiva tränare. Utse en annan tränare innan du ändrar eller inaktiverar den här medlemmen.",
  invalid: "Medlemmen kunde inte hittas. Ladda om sidan.",
};

export function TeamMemberListView({
  members,
  inviteError,
  mutationError,
}: {
  members: TeamMemberListItem[];
  inviteError: string | null;
  mutationError: string | null;
}) {
  const active = members.filter((member) => member.isActive);
  const inactive = members.filter((member) => !member.isActive);
  const activeCoachCount = active.filter((member) => member.role === "coach").length;

  return (
    <section aria-labelledby="team-members-heading" className="space-y-8">
      <header>
        <h1 id="team-members-heading" className="text-2xl font-semibold text-slate-950">
          Medlemmar
        </h1>
        <p className="mt-2 text-sm text-slate-500">
          Hantera vilka som har åtkomst till laget och vilken roll de har. Tränare ser och gör allt; besökare kan bara läsa Kommande, Träningar och Matcher.
        </p>
      </header>

      {mutationError ? (
        <p role="alert" className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-950">
          {mutationErrorText[mutationError] ?? "Ändringen kunde inte genomföras."}
        </p>
      ) : null}

      <section aria-labelledby="active-members-heading" className="space-y-3">
        <h2 id="active-members-heading" className="text-lg font-semibold text-slate-950">
          Aktiva medlemmar
        </h2>
        {active.length === 0 ? (
          <p className="text-sm text-slate-600">Inga aktiva medlemmar.</p>
        ) : (
          <ul className="space-y-3">
            {active.map((member) => {
              const isLastActiveCoach = member.role === "coach" && activeCoachCount <= 1;
              return (
                <li key={member.userId} className="rounded-2xl bg-white p-4 shadow-sm ring-1 ring-slate-200/70">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div className="min-w-0">
                      <p className="truncate font-semibold text-slate-950">{member.email}</p>
                      <p className="text-xs text-slate-500">{roleLabels[member.role] ?? member.role}</p>
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                      <form action={`/team/${member.userId}/role`} method="post" className="flex items-center gap-2">
                        <input type="hidden" name="fingerprint" value={member.fingerprint} />
                        <label className="sr-only" htmlFor={`role-${member.userId}`}>
                          Roll för {member.email}
                        </label>
                        <select
                          id={`role-${member.userId}`}
                          name="role"
                          defaultValue={member.role}
                          disabled={isLastActiveCoach}
                          title={isLastActiveCoach ? "Lagets sista aktiva tränare kan inte ändras. Utse en annan tränare först." : undefined}
                          className="min-h-11 rounded-xl border border-slate-300 bg-white px-3 text-sm text-slate-950 disabled:cursor-not-allowed disabled:opacity-50"
                        >
                          <option value="coach">Tränare</option>
                          <option value="viewer">Besökare</option>
                        </select>
                        <button
                          type="submit"
                          disabled={isLastActiveCoach}
                          className="min-h-11 rounded-xl border border-slate-300 px-3 text-sm font-semibold text-slate-800 hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
                        >
                          Byt roll
                        </button>
                      </form>
                      <form action={`/team/${member.userId}/deactivate`} method="post">
                        <input type="hidden" name="fingerprint" value={member.fingerprint} />
                        <button
                          type="submit"
                          disabled={isLastActiveCoach}
                          title={isLastActiveCoach ? "Lagets sista aktiva tränare kan inte inaktiveras. Utse en annan tränare först." : undefined}
                          className="min-h-11 rounded-xl border border-red-200 px-3 text-sm font-semibold text-red-800 hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-50"
                        >
                          Inaktivera
                        </button>
                      </form>
                    </div>
                  </div>
                  {isLastActiveCoach ? (
                    <p className="mt-2 text-xs text-amber-700">Lagets sista aktiva tränare. Utse en annan tränare innan du ändrar eller inaktiverar den här medlemmen.</p>
                  ) : null}
                </li>
              );
            })}
          </ul>
        )}
      </section>

      {inactive.length > 0 ? (
        <section aria-labelledby="inactive-members-heading" className="space-y-3">
          <h2 id="inactive-members-heading" className="text-lg font-semibold text-slate-950">
            Inaktiverade medlemmar
          </h2>
          <ul className="space-y-3">
            {inactive.map((member) => (
              <li key={member.userId} className="rounded-2xl border border-dashed border-slate-300 bg-white p-4">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div className="min-w-0">
                    <p className="truncate font-semibold text-slate-700">{member.email}</p>
                    <p className="text-xs text-slate-500">{roleLabels[member.role] ?? member.role}</p>
                  </div>
                  <form action={`/team/${member.userId}/reactivate`} method="post">
                    <input type="hidden" name="fingerprint" value={member.fingerprint} />
                    <button type="submit" className="min-h-11 rounded-xl border border-slate-300 px-3 text-sm font-semibold text-slate-800 hover:bg-slate-50">
                      Återaktivera
                    </button>
                  </form>
                </div>
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      <section aria-labelledby="invite-member-heading" className="space-y-3 rounded-2xl border border-slate-200 bg-white p-5">
        <h2 id="invite-member-heading" className="text-lg font-semibold text-slate-950">
          Bjud in ny medlem
        </h2>
        <p className="text-sm text-slate-600">Personen får ett e-postmeddelande med en länk där de sätter sitt eget lösenord.</p>
        {inviteError ? (
          <p role="alert" className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
            {inviteErrorText[inviteError] ?? "Inbjudan kunde inte skickas."}
          </p>
        ) : null}
        <form action="/team/invite" method="post" className="flex flex-wrap items-end gap-3">
          <div className="min-w-0 flex-1">
            <label htmlFor="invite-email" className="text-sm font-medium text-slate-800">
              E-postadress
            </label>
            <input
              id="invite-email"
              name="email"
              type="email"
              required
              autoComplete="email"
              className="mt-2 min-h-11 w-full rounded-xl border border-slate-300 bg-white px-4 text-sm text-slate-950"
            />
          </div>
          <div>
            <label htmlFor="invite-role" className="text-sm font-medium text-slate-800">
              Roll
            </label>
            <select id="invite-role" name="role" defaultValue="viewer" className="mt-2 min-h-11 rounded-xl border border-slate-300 bg-white px-3 text-sm text-slate-950">
              <option value="coach">Tränare</option>
              <option value="viewer">Besökare</option>
            </select>
          </div>
          <button type="submit" className="min-h-11 rounded-xl bg-blue-700 px-4 text-sm font-semibold text-white hover:bg-blue-800">
            Skicka inbjudan
          </button>
        </form>
      </section>
    </section>
  );
}
