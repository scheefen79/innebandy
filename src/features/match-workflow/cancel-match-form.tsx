"use client";

import { useState } from "react";

export function CancelMatchForm({ action, revision, requestId, disabled = false, onSubmit }: {
  action: string;
  revision: number;
  requestId: string;
  disabled?: boolean;
  onSubmit?: () => void;
}) {
  const [submitted, setSubmitted] = useState(false);
  return <details id="cancel-match" className="rounded-xl border border-red-100 bg-white p-4">
    <summary className="min-h-11 cursor-pointer font-semibold text-red-700">Ställ in matchen</summary>
    <p className="my-3 text-sm text-slate-600">Matchen markeras som inställd och räknas bort från fördelningen. Därefter får du granska och spara en ny grundplan för resterande matcher. Påbörjade matchveckor, spelade matcher och manuella beslut bevaras.</p>
    <form action={action} method="post" onSubmit={() => { setSubmitted(true); onSubmit?.(); }}>
      <input type="hidden" name="action" value="cancel" />
      <input type="hidden" name="revision" value={revision} />
      <input type="hidden" name="requestId" value={requestId} />
      <button disabled={disabled || submitted} className="min-h-12 rounded-xl border border-red-300 px-4 py-3 font-semibold text-red-800 disabled:text-slate-400">{submitted ? "Ställer in…" : "Ställ in och förhandsgranska"}</button>
    </form>
  </details>;
}
