"use client";
import {AppShell} from "@/components/app-shell";
import Link from "next/link";
export default function PlayersError({reset}:{reset:()=>void}){return <AppShell currentItem="Spelare"><section role="alert" className="rounded-2xl bg-white px-5 py-10 text-center shadow-sm"><h1 className="text-xl font-semibold text-slate-950">Spelarna kunde inte hämtas</h1><p className="mt-2 text-sm text-slate-600">Försök igen eller gå tillbaka till översikten.</p><div className="mt-5 flex justify-center gap-3"><button onClick={reset} className="min-h-11 rounded-xl bg-[#082B4C] px-5 text-sm font-semibold text-white">Försök igen</button><Link href="/" className="inline-flex min-h-11 items-center text-sm font-semibold text-blue-700 underline">Kommande</Link></div></section></AppShell>}
