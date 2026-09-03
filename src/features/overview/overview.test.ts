import type { SupabaseClient } from "@supabase/supabase-js";
import {describe,expect,it,vi} from "vitest";
import {groupRegularCounts,hasFairnessWarning,loadOverview} from "./overview";

describe("overview",()=>{
 it("groups regular counts with Swedish labels",()=>expect(groupRegularCounts([{id:"a",name:"A",regularCount:2},{id:"b",name:"B",regularCount:0},{id:"c",name:"C",regularCount:2},{id:"d",name:"D",regularCount:1}])).toEqual([
  {regularCount:0,playerCount:1,label:"0 ordinarie matcher – 1 spelare"},{regularCount:1,playerCount:1,label:"1 ordinarie match – 1 spelare"},{regularCount:2,playerCount:2,label:"2 ordinarie matcher – 2 spelare"}
 ]));
 it("warns only when the regular difference exceeds one",()=>{expect(hasFairnessWarning([{id:"a",name:"A",regularCount:1},{id:"b",name:"B",regularCount:2}])).toBe(false);expect(hasFairnessWarning([{id:"a",name:"A",regularCount:0},{id:"b",name:"B",regularCount:2}])).toBe(true);});
 it("loads the atomic home envelope including role and next training",async()=>{const payload={seasonName:"Säsong",serverNow:"2026-08-24T12:00:00Z",role:"viewer" as const,nextTraining:{id:"t1",startsAt:"2026-09-05T08:00:00Z",endsAt:"2026-09-05T09:00:00Z",themeBlock:1,focus:"Passningar",keyMessage:"PASSA",status:"draft" as const},upcomingMatches:[],players:[]};const rpc=vi.fn().mockResolvedValue({data:payload,error:null});await expect(loadOverview({rpc} as unknown as SupabaseClient)).resolves.toEqual(payload);expect(rpc).toHaveBeenCalledWith("get_home_overview");});
});
