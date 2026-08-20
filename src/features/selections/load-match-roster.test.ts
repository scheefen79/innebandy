import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { loadMatchRoster } from "./load-match-roster";

function queryWith(result: { data: unknown; error: unknown }) {
  const filters: Array<[string, unknown]> = [];
  const query = {
    eq: vi.fn((column: string, value: unknown) => { filters.push([column, value]); return query; }),
    order: vi.fn(async () => result),
    select: vi.fn(() => query),
    then: (resolve: (value: typeof result) => unknown) => Promise.resolve(result).then(resolve),
  };
  return { filters, query };
}

describe("loadMatchRoster", () => {
  it("separates selected players from players standing over inside team and season", async () => {
    const players = queryWith({ data: [
      { id: "player-1", first_name: "Ada", last_name: "Ett", level: 1, rotation_order: 1 },
      { id: "player-2", first_name: "Bea", last_name: null, level: 2, rotation_order: 2 },
    ], error: null });
    const selections = queryWith({ data: [{ player_id: "player-2" }], error: null });
    const from = vi.fn((table: string) => table === "players" ? players.query : selections.query);

    await expect(loadMatchRoster({ from } as unknown as SupabaseClient, "team-1", "season-1", "match-1")).resolves.toEqual([
      { id: "player-1", name: "Ada Ett", level: 1, selected: false },
      { id: "player-2", name: "Bea", level: 2, selected: true },
    ]);
    expect(players.filters).toEqual([["team_id", "team-1"], ["season_id", "season-1"], ["is_active", true]]);
    expect(selections.filters).toEqual([
      ["team_id", "team-1"], ["season_id", "season-1"], ["match_id", "match-1"],
      ["selection_type", "regular"], ["selection_status", "selected"],
    ]);
  });
});
