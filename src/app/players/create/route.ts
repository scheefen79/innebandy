import { NextRequest, NextResponse } from "next/server";
import { createPlayer, validatePlayerInput } from "@/features/players/player-management";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createAdminClient } from "@/lib/supabase/admin";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";

export async function POST(request: NextRequest) {
  const {applyAuthState,supabase}=createRouteHandlerClient(request); const go=(path:string)=>applyAuthState(NextResponse.redirect(new URL(path,request.url),303)); const userId=await getVerifiedUserId(); if(!userId)return go("/login?next=/players/new");
  const context=await loadTeamContext(supabase); if(!context)return go("/access-denied"); const form=await request.formData(); const validated=validatePlayerInput(Object.fromEntries(["first_name","last_name","level"].map(key=>[key,String(form.get(key)??"")]))); if(!validated.ok)return go(`/players/new?error=${encodeURIComponent(validated.error)}`);
  const result=await createPlayer(createAdminClient(),{...validated.value,actorUserId:userId,teamId:context.teamId,seasonId:context.seasonId,requestId:String(form.get("request_id")??"")}); if(result.status!=="ok")return go("/players/new?error=Formuläret kunde inte sparas. Ladda om och försök igen."); return go(`/players/${result.playerId}?change=created`);
}
