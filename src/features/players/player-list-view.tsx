import type { PlayerListItem } from "./player-list";

type PlayerListViewProps = {
  players: PlayerListItem[];
  seasonName: string;
};

const levelStyles = {
  1: "bg-emerald-50 text-emerald-800 ring-emerald-200",
  2: "bg-amber-50 text-amber-800 ring-amber-200",
  3: "bg-slate-100 text-slate-700 ring-slate-200",
};

export function PlayerListView({ players, seasonName }: PlayerListViewProps) {
  return (
    <section aria-labelledby="players-heading" className="space-y-5">
      <header>
        <p className="text-sm font-medium text-slate-500">{seasonName}</p>
        <div className="mt-1 flex items-end justify-between gap-4">
          <h1 id="players-heading" className="text-2xl font-semibold tracking-tight text-slate-950">
            Spelare
          </h1>
          <p className="shrink-0 text-sm text-slate-500">
            {players.length} {players.length === 1 ? "aktiv" : "aktiva"}
          </p>
        </div>
      </header>

      {players.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-slate-300 bg-white px-5 py-10 text-center shadow-sm">
          <h2 className="text-lg font-semibold text-slate-950">Inga spelare ännu</h2>
          <p className="mx-auto mt-2 max-w-sm text-sm leading-6 text-slate-600">
            Spelare läggs till i ett kommande steg.
          </p>
        </div>
      ) : (
        <ul aria-label="Aktiva spelare" className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {players.map((player) => (
            <li key={player.id} className="flex min-w-0 items-center justify-between gap-3 rounded-2xl bg-white p-4 shadow-sm ring-1 ring-slate-200/70">
              <p className="min-w-0 truncate font-semibold text-slate-950">{player.name}</p>
              <span className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset ${levelStyles[player.level]}`}>
                {player.levelLabel}
              </span>
            </li>
          ))}
        </ul>
      )}

      <p className="text-xs leading-5 text-slate-500">
        Nivå 1 är högst och nivå 3 är lägst. Nivån används endast för att balansera lag.
      </p>
    </section>
  );
}
