import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { loadMatch, loadMatches } from "./load-matches";

type QueryResult = { data: unknown; error: unknown };

function createQuery(result: QueryResult) {
  const calls: Array<[string, string, unknown]> = [];
  const query = {
    eq: vi.fn((column: string, value: unknown) => { calls.push(["eq", column, value]); return query; }),
    gte: vi.fn((column: string, value: unknown) => { calls.push(["gte", column, value]); return query; }),
    in: vi.fn((column: string, value: unknown) => { calls.push(["in", column, value]); return query; }),
    maybeSingle: vi.fn(async () => result),
    order: vi.fn(async (column: string, options: unknown) => { calls.push(["order", column, options]); return result; }),
    select: vi.fn(() => query),
    then: (resolve: (value: QueryResult) => unknown) => Promise.resolve(result).then(resolve),
  };
  return { calls, query };
}

const row = {
  id: "match-1", opponent: "Täby FC", starts_at: "2026-09-10T16:30:00.000Z",
  location: null, target_players: 8, status: "upcoming",
};

describe("match queries", () => {
  it("loads only future upcoming matches for the active team and season", async () => {
    const rpc=vi.fn().mockResolvedValue({data:[{id:"match-1",opponent:"Täby FC",startsAt:row.starts_at,location:null,targetPlayers:8,status:"upcoming",selectedPlayers:1}],error:null});
    const result = await loadMatches({ rpc } as unknown as SupabaseClient, "team-1", "season-1", "upcoming", "2026-08-17T10:00:00.000Z");
    expect(rpc).toHaveBeenCalledWith("get_match_list",{target_team_id:"team-1",target_season_id:"season-1",requested_filter:"upcoming",requested_now:"2026-08-17T10:00:00.000Z"});
    expect(result[0]).toMatchObject({ id: "match-1", selectedPlayers: 1, startsAt: row.starts_at, targetPlayers: 8 });
  });

  it("loads all season matches descending without a time or status filter", async () => {
    const rpc=vi.fn().mockResolvedValue({data:[],error:null});
    await loadMatches({rpc} as unknown as SupabaseClient,"team-1","season-1","all","now");
    expect(rpc).toHaveBeenCalledWith("get_match_list",expect.objectContaining({requested_filter:"all"}));
  });

  it("scopes a detail lookup to both team and season and returns null when hidden", async () => {
    const source = createQuery({ data: null, error: null });
    await expect(loadMatch({ from: vi.fn(() => source.query) } as unknown as SupabaseClient, "team-1", "season-1", "550e8400-e29b-41d4-a716-446655440000")).resolves.toBeNull();
    expect(source.calls).toEqual([
      ["eq", "id", "550e8400-e29b-41d4-a716-446655440000"], ["eq", "team_id", "team-1"], ["eq", "season_id", "season-1"],
    ]);
  });

  it("returns the generic hidden result for a malformed match id without querying Postgres", async () => {
    const from = vi.fn();
    await expect(loadMatch({ from } as unknown as SupabaseClient, "team-1", "season-1", "inte-en-uuid")).resolves.toBeNull();
    expect(from).not.toHaveBeenCalled();
  });
});
