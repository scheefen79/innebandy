import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { loadMatchRoster } from "./load-match-roster";

describe("loadMatchRoster", () => {
  it("separates selected players from players standing over inside team and season", async () => {
    const data=[
      { id: "player-1", name: "Ada Ett", level: 1, isActive: true, selected: false, selectionSource: null, selectionStatus: null, selectionType: null, replacedPlayerId: null, played: false },
      { id: "player-2", name: "Bea", level: 2, isActive: true, selected: true, selectionSource: "manual", selectionStatus: "selected", selectionType: "regular", replacedPlayerId: "player-1", played: false },
    ];
    const rpc=vi.fn().mockResolvedValue({data,error:null});
    await expect(loadMatchRoster({rpc} as unknown as SupabaseClient,"team-1","season-1","match-1")).resolves.toEqual(data);
    expect(rpc).toHaveBeenCalledWith("get_match_roster",{target_team_id:"team-1",target_season_id:"season-1",target_match_id:"match-1"});
  });
  it("accepts a minimized viewer roster without player levels",async()=>{
    const rpc=vi.fn().mockResolvedValue({data:[{id:"player-1",name:"Ada Ett",rosterGroup:"team"}],error:null});
    await expect(loadMatchRoster({rpc} as unknown as SupabaseClient,"team-1","season-1","match-1")).resolves.toEqual([{id:"player-1",name:"Ada Ett",level:null,isActive:true,selected:true,selectionSource:null,selectionStatus:"selected",selectionType:"regular",replacedPlayerId:null,played:null}]);
  });
});
