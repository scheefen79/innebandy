"use client";
import Link from "next/link";
import { useMemo, useState } from "react";
import type { PlayerListItem } from "./player-list";

const levelStyles = { 1: "bg-emerald-50 text-emerald-800 ring-emerald-200", 2: "bg-amber-50 text-amber-800 ring-amber-200", 3: "bg-slate-100 text-slate-700 ring-slate-200" };

export function PlayerListView({ players, seasonName }: { players: PlayerListItem[]; seasonName: string }) {
  const [query, setQuery] = useState("");
  const visible = useMemo(() => players.filter((player) => player.name.toLocaleLowerCase("sv").includes(query.trim().toLocaleLowerCase("sv"))), [players, query]);
  return <section aria-labelledby="players-heading" className="space-y-5">
    <header><p className="text-sm font-medium text-slate-500">{seasonName}</p><div className="mt-1 flex items-end justify-between gap-4"><h1 id="players-heading" className="text-2xl font-semibold text-slate-950">Spelare</h1><Link href="/players/new" className="inline-flex min-h-11 items-center rounded-xl bg-blue-700 px-4 text-sm font-semibold text-white">Lägg till spelare</Link></div><p className="mt-2 text-sm text-slate-500">{players.length} {players.length === 1 ? "aktiv" : "aktiva"}</p></header>
    {players.length > 0 ? <div><label htmlFor="player-search" className="text-sm font-semibold text-slate-800">Sök spelare</label><input id="player-search" type="search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Skriv ett namn" className="mt-2 min-h-12 w-full rounded-xl border border-slate-300 bg-white px-4 text-slate-950" /></div> : null}
    {players.length === 0 ? <div className="rounded-2xl border border-dashed border-slate-300 bg-white px-5 py-10 text-center"><h2 className="text-lg font-semibold text-slate-950">Inga spelare ännu</h2><p className="mt-2 text-sm text-slate-600">Lägg till den första spelaren i den aktiva säsongen.</p><Link href="/players/new" className="mt-5 inline-flex min-h-11 items-center rounded-xl bg-blue-700 px-4 font-semibold text-white">Lägg till spelare</Link></div> : visible.length === 0 ? <div className="rounded-xl bg-white p-5 text-sm text-slate-600">Ingen spelare matchar sökningen.</div> : <ul aria-label="Aktiva spelare" className="grid gap-3 sm:grid-cols-2">{visible.map((player) => <li key={player.id}><Link href={`/players/${player.id}`} className="block min-w-0 rounded-2xl bg-white p-4 shadow-sm ring-1 ring-slate-200/70"><div className="flex items-center justify-between gap-3"><span className="truncate font-semibold text-slate-950">{player.name}</span><span className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset ${levelStyles[player.level]}`}>{player.levelLabel}</span></div><dl className="mt-4 grid grid-cols-2 gap-3 text-xs"><div><dt className="text-slate-500">Ordinarie</dt><dd className="mt-1 font-semibold text-slate-800">{player.plannedRegular} planerade · {player.completedRegular} spelade</dd></div><div><dt className="text-slate-500">Extra inhopp</dt><dd className="mt-1 font-semibold text-slate-800">{player.plannedExtra} planerade · {player.completedExtra} spelade</dd></div></dl></Link></li>)}</ul>}
    <p className="text-xs text-slate-500">Nivå 1 är högst och nivå 3 är lägst. Nivån används endast för att balansera lag.</p>
  </section>;
}
