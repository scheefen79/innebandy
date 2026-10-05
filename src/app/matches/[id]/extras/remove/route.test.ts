import { NextRequest } from "next/server";
import { beforeEach, expect, it, vi } from "vitest";
const auth=vi.hoisted(()=>({user:vi.fn(),context:vi.fn()}));
vi.mock("@/lib/supabase/route-handler",()=>({createRouteHandlerClient:()=>({supabase:{},applyAuthState:(r:Response)=>r})}));
vi.mock("@/lib/auth/verified-user",()=>({getVerifiedUserId:auth.user}));
vi.mock("@/lib/auth/team-context",()=>({loadTeamContext:auth.context}));
import { POST } from "./route";
const id="d5000000-0000-4000-8000-000000000001";
beforeEach(()=>{auth.user.mockResolvedValue("coach");auth.context.mockResolvedValue({role:"coach"});});
it("redirects old submissions into matchweek without saving the old payload",async()=>{
 const response=await POST(new NextRequest("https://app.example/legacy",{method:"POST",body:"old=payload"}),{params:Promise.resolve({id})});
 expect(response.status).toBe(303);expect(response.headers.get("location")).toBe(`https://app.example/matches/${id}/week`);
});
it("denies viewer and unauthenticated submissions",async()=>{
 auth.context.mockResolvedValue({role:"viewer"});
 expect((await POST(new NextRequest("https://app.example/legacy",{method:"POST"}),{params:Promise.resolve({id})})).headers.get("location")).toContain("/access-denied");
 auth.user.mockResolvedValue(null);
 expect((await POST(new NextRequest("https://app.example/legacy",{method:"POST"}),{params:Promise.resolve({id})})).headers.get("location")).toContain("/login");
});
