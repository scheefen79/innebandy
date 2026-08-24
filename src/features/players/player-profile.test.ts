import type { SupabaseClient } from "@supabase/supabase-js";
import { expect,it,vi } from "vitest";
import { loadPlayerProfile,summarizePlayerMatches } from "./player-profile";

it("loads all decisions but counts only selected regular and extra history separately",async()=>{const matches=[
 {id:"1",opponent:"A",startsAt:"2027-01-01",location:null,status:"upcoming",selectionType:"regular",selectionSource:"automatic",selectionStatus:"selected",played:false},
 {id:"2",opponent:"B",startsAt:"2026-01-01",location:null,status:"completed",selectionType:"regular",selectionSource:"manual",selectionStatus:"selected",played:false},
 {id:"3",opponent:"C",startsAt:"2026-01-02",location:null,status:"completed",selectionType:"extra",selectionSource:"manual",selectionStatus:"selected",played:true},
 {id:"4",opponent:"D",startsAt:"2027-01-03",location:null,status:"upcoming",selectionType:"regular",selectionSource:"manual",selectionStatus:"removed",played:false},
];const rpc=vi.fn().mockResolvedValue({data:{fingerprint:"fp",serverNow:"2026-08-24T12:00:00Z",player:{id:"p",firstName:"Ada",lastName:null,level:1,isActive:true},matches},error:null});const profile=await loadPlayerProfile({rpc} as unknown as SupabaseClient,"t","s","p");expect(profile?.matches).toHaveLength(4);expect(profile?.matches.map(match=>match.isFuture)).toEqual([true,false,false,true]);expect(summarizePlayerMatches(profile!.matches)).toEqual({plannedRegular:1,completedRegular:0,plannedExtra:0,completedExtra:1});});
