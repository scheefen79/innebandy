import type { SupabaseClient } from "@supabase/supabase-js";
import { describe,expect,it,vi } from "vitest";
import { createPlayer,mutatePlayer,validatePlayerInput } from "./player-management";

describe("player management",()=>{
 it("normalizes valid input and rejects invalid names and levels",()=>{expect(validatePlayerInput({first_name:" Ada ",last_name:" Ett ",level:"1"})).toEqual({ok:true,value:{firstName:"Ada",lastName:"Ett",level:1}});expect(validatePlayerInput({first_name:"",last_name:"",level:"2"}).ok).toBe(false);expect(validatePlayerInput({first_name:"Ada",last_name:"",level:"4"}).ok).toBe(false);});
 it("creates through the server RPC with a stable request id",async()=>{const rpc=vi.fn().mockResolvedValue({data:"player-id",error:null});await expect(createPlayer({rpc} as unknown as SupabaseClient,{firstName:"Ada",lastName:null,level:2,actorUserId:"actor",teamId:"team",seasonId:"season",requestId:"f7000000-0000-4000-8000-000000000001"})).resolves.toEqual({status:"ok",playerId:"player-id"});expect(rpc).toHaveBeenCalledWith("create_player",expect.objectContaining({request_id:"f7000000-0000-4000-8000-000000000001"}));});
 it("maps stale and blocked mutations",async()=>{const input={firstName:"Ada",lastName:null,level:2 as const,actorUserId:"actor",teamId:"team",seasonId:"season",playerId:"player",fingerprint:"fp"};const stale=vi.fn().mockResolvedValue({error:{message:"STALE_PLAYER"}});await expect(mutatePlayer({rpc:stale} as unknown as SupabaseClient,"update_player",input)).resolves.toBe("stale");const blocked=vi.fn().mockResolvedValue({error:{message:"PLAYER_HAS_PLANNED_DECISIONS"}});await expect(mutatePlayer({rpc:blocked} as unknown as SupabaseClient,"deactivate_player",input)).resolves.toBe("blocked");});
});
