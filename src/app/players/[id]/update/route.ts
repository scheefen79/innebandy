import { NextRequest,NextResponse } from "next/server";
import { isUuid } from "@/features/matches/match-validation";
import { mutatePlayer,validatePlayerInput } from "@/features/players/player-management";
import { loadTeamContext } from "@/lib/auth/team-context";
import { createAdminClient } from "@/lib/supabase/admin";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";

export async function POST(request:NextRequest,{params}:{params:Promise<{id:string}>}){const {id}=await params;const {applyAuthState,supabase}=createRouteHandlerClient(request);const go=(path:string)=>applyAuthState(NextResponse.redirect(new URL(path,request.url),303));const {data}=await supabase.auth.getClaims();if(!data?.claims?.sub)return go(`/login?next=${encodeURIComponent(`/players/${id}`)}`);const context=await loadTeamContext(supabase);if(!context)return go("/access-denied");const form=await request.formData();const validated=validatePlayerInput(Object.fromEntries(["first_name","last_name","level"].map(key=>[key,String(form.get(key)??"")])));const fingerprint=String(form.get("fingerprint")??"");if(!isUuid(id)||!/^[a-f0-9]{32}$/.test(fingerprint)||!validated.ok)return go(`/players/${id}/edit?error=invalid`);const result=await mutatePlayer(createAdminClient(),"update_player",{...validated.value,actorUserId:data.claims.sub,teamId:context.teamId,seasonId:context.seasonId,playerId:id,fingerprint});if(result!=="ok")return go(`/players/${id}/edit?error=${result}`);return go(`/players/${id}?change=updated`);}
