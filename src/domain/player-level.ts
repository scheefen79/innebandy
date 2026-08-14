export type PlayerLevel = 1 | 2 | 3;

const playerLevelLabels: Record<PlayerLevel, string> = {
  1: "Nivå 1 · Högst",
  2: "Nivå 2 · Mellan",
  3: "Nivå 3 · Lägst",
};

export function getPlayerLevelLabel(level: PlayerLevel): string {
  return playerLevelLabels[level];
}
