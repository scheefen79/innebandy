import { getPlayerLevelLabel, type PlayerLevel } from "@/domain/player-level";

export type PlayerRow = {
  id: string;
  first_name: string;
  last_name: string | null;
  level: number;
  rotation_order: number;
};

export type PlayerListItem = {
  id: string;
  name: string;
  level: PlayerLevel;
  levelLabel: string;
};

function isPlayerLevel(level: number): level is PlayerLevel {
  return level === 1 || level === 2 || level === 3;
}

export function toPlayerListItems(rows: PlayerRow[]): PlayerListItem[] {
  return [...rows]
    .sort((left, right) => left.rotation_order - right.rotation_order)
    .map((row) => {
      if (!isPlayerLevel(row.level)) {
        throw new Error("Spelaren har en ogiltig nivå.");
      }

      return {
        id: row.id,
        name: [row.first_name.trim(), row.last_name?.trim()].filter(Boolean).join(" "),
        level: row.level,
        levelLabel: getPlayerLevelLabel(row.level),
      };
    });
}
