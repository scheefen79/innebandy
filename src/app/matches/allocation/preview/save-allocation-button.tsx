"use client";

import { useFormStatus } from "react-dom";

export function SaveAllocationButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending} className="min-h-12 w-full rounded-xl bg-blue-700 px-4 font-semibold text-white hover:bg-blue-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-700 disabled:cursor-wait disabled:bg-blue-400">{pending ? "Sparar fördelning…" : "Spara fördelning"}</button>;
}
