import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";

import { loadPlayerList } from "./load-player-list";

type QueryResult = {
  data: unknown;
  error: unknown;
};

function createQuery(result: QueryResult) {
  const filters: Array<[string, unknown]> = [];
  const query = {
    eq: vi.fn((column: string, value: unknown) => {
      filters.push([column, value]);
      return query;
    }),
    maybeSingle: vi.fn(async () => result),
    order: vi.fn(async () => result),
    select: vi.fn(() => query),
  };

  return { filters, query };
}

describe("loadPlayerList", () => {
  it("hämtar endast aktiva spelare för rätt lag och aktiv säsong", async () => {
    const season = createQuery({
      data: { id: "season-1", name: "Testsäsong" },
      error: null,
    });
    const players = createQuery({
      data: [
        {
          id: "player-1",
          first_name: "Ada",
          last_name: "Lovelace",
          level: 1,
          rotation_order: 1,
        },
      ],
      error: null,
    });
    const from = vi.fn((table: string) =>
      table === "seasons" ? season.query : players.query,
    );

    const result = await loadPlayerList(
      { from } as unknown as SupabaseClient,
      "team-1",
    );

    expect(from.mock.calls.map(([table]) => table)).toEqual(["seasons", "players"]);
    expect(season.filters).toEqual([
      ["team_id", "team-1"],
      ["is_active", true],
    ]);
    expect(players.filters).toEqual([
      ["team_id", "team-1"],
      ["season_id", "season-1"],
      ["is_active", true],
    ]);
    expect(players.query.order).toHaveBeenCalledWith("rotation_order");
    expect(result).toEqual({
      players: [
        {
          id: "player-1",
          name: "Ada Lovelace",
          level: 1,
          levelLabel: "Nivå 1 · Högst",
        },
      ],
      seasonName: "Testsäsong",
    });
  });

  it("stoppar listan när laget saknar en aktiv säsong", async () => {
    const season = createQuery({ data: null, error: null });
    const from = vi.fn(() => season.query);

    await expect(
      loadPlayerList({ from } as unknown as SupabaseClient, "team-1"),
    ).rejects.toThrow("Laget saknar en aktiv säsong.");
  });
});
