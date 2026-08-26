import type {SupabaseClient} from "@supabase/supabase-js";
import {describe,expect,it,vi} from "vitest";
import {loadTeamContext} from "./team-context";

describe("team context",()=>{
 it("loads membership and active season in one RPC",async()=>{
  const rpc=vi.fn().mockResolvedValue({data:{teamId:"team",seasonId:"season",seasonName:"Höstterminen 2026"},error:null});
  await expect(loadTeamContext({rpc} as unknown as SupabaseClient)).resolves.toEqual({teamId:"team",seasonId:"season",seasonName:"Höstterminen 2026"});
  expect(rpc).toHaveBeenCalledTimes(1);expect(rpc).toHaveBeenCalledWith("get_team_context");
 });
 it("returns null when no active context exists",async()=>{
  const rpc=vi.fn().mockResolvedValue({data:null,error:{message:"TEAM_CONTEXT_NOT_AVAILABLE"}});
  await expect(loadTeamContext({rpc} as unknown as SupabaseClient)).resolves.toBeNull();
 });
});
