import {renderToStaticMarkup} from "react-dom/server";
import {beforeEach,describe,expect,it,vi} from "vitest";

const state=vi.hoisted(()=>({authenticated:true}));
const redirectMock=vi.hoisted(()=>vi.fn((path:string)=>{throw new Error(`REDIRECT:${path}`)}));
const loadTeamContextMock=vi.hoisted(()=>vi.fn());
const loadPlayerListMock=vi.hoisted(()=>vi.fn());

vi.mock("next/navigation",()=>({redirect:redirectMock}));
vi.mock("@/lib/supabase/server",()=>({createClient:vi.fn(async()=>({auth:{getClaims:vi.fn(async()=>({data:{claims:state.authenticated?{sub:"coach"}:null}}))}}))}));
vi.mock("@/lib/auth/team-context",()=>({loadTeamContext:loadTeamContextMock}));
vi.mock("@/features/players/load-player-list",()=>({loadPlayerList:loadPlayerListMock}));

import PlayersPage from "./page";

describe("players page route",()=>{
 beforeEach(()=>{state.authenticated=true;redirectMock.mockClear();loadTeamContextMock.mockResolvedValue({teamId:"team",seasonId:"season",seasonName:"Säsong"});loadPlayerListMock.mockResolvedValue({seasonName:"Säsong",players:[]});});
 it("redirects an unauthenticated visitor to login with the new route",async()=>{state.authenticated=false;await expect(PlayersPage()).rejects.toThrow("REDIRECT:/login?next=/players");expect(redirectMock).toHaveBeenCalledWith("/login?next=/players");});
 it("redirects a visitor without active team context",async()=>{loadTeamContextMock.mockResolvedValue(null);await expect(PlayersPage()).rejects.toThrow("REDIRECT:/access-denied");expect(redirectMock).toHaveBeenCalledWith("/access-denied");});
 it("renders the protected player list at /players",async()=>{const html=renderToStaticMarkup(await PlayersPage());expect(html).toContain("Spelare");expect(html).toContain("Inga spelare ännu");expect(loadPlayerListMock).toHaveBeenCalledWith(expect.anything(),"team");});
});
