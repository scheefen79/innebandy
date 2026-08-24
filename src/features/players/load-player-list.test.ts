import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";

import { loadPlayerList } from "./load-player-list";

describe("loadPlayerList", () => {
  it("hämtar spelare och kanoniska räknare atomiskt", async () => {
    const rpc = vi.fn().mockResolvedValue({data:{seasonName:"Testsäsong",players:[{id:"player-1",firstName:"Ada",lastName:"Lovelace",level:1,plannedRegular:0,completedRegular:1,plannedExtra:0,completedExtra:0}]},error:null});

    const result = await loadPlayerList(
      { rpc } as unknown as SupabaseClient,
      "team-1",
    );

    expect(rpc).toHaveBeenCalledWith("get_player_list",{target_team_id:"team-1"});
    expect(result).toEqual({
      players: [
        {
          id: "player-1",
          name: "Ada Lovelace",
          level: 1,
          levelLabel: "Nivå 1 · Högst",
          plannedRegular: 0, completedRegular: 1, plannedExtra: 0, completedExtra: 0,
        },
      ],
      seasonName: "Testsäsong",
    });
  });

  it("stoppar listan när laget saknar en aktiv säsong", async () => {
    const rpc = vi.fn().mockResolvedValue({data:null,error:{message:"ACTIVE_SEASON_NOT_AVAILABLE"}});

    await expect(
      loadPlayerList({ rpc } as unknown as SupabaseClient, "team-1"),
    ).rejects.toThrow("Laget saknar en aktiv säsong.");
  });
});
