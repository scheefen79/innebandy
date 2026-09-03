import { NextRequest } from "next/server";
import { expect,it,vi } from "vitest";
const mutate=vi.hoisted(()=>vi.fn().mockResolvedValue("blocked"));
vi.mock("@/lib/supabase/route-handler",()=>({createRouteHandlerClient:()=>({applyAuthState:(r:Response)=>r,supabase:{}})}));vi.mock("@/lib/auth/verified-user",()=>({getVerifiedUserId:async()=>"actor"}));vi.mock("@/lib/auth/team-context",()=>({loadTeamContext:async()=>({teamId:"team",seasonId:"season",role:"coach"})}));vi.mock("@/lib/supabase/admin",()=>({createAdminClient:()=>({})}));vi.mock("@/features/players/player-management",()=>({mutatePlayer:mutate}));
import { POST } from "./route";
it("returns blocked state when planned manual or extra decisions remain",async()=>{const id="f4000000-0000-4000-8000-000000000001";const response=await POST(new NextRequest(`https://app.example/players/${id}/deactivate`,{method:"POST",body:new URLSearchParams({fingerprint:"a".repeat(32)})}),{params:Promise.resolve({id})});expect(response.headers.get("location")).toBe(`https://app.example/players/${id}/edit?error=blocked`);});
