import { NextRequest, NextResponse } from "next/server";
import { isUuid } from "@/features/matches/match-validation";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";
/** Old form submissions must not bypass the invitation, capacity and locking rules. */
export async function redirectLegacyMatchPost(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { supabase, applyAuthState } = createRouteHandlerClient(request);
  const redirectTo = (path: string) => applyAuthState(NextResponse.redirect(new URL(path, request.url),303));
  if (!await getVerifiedUserId()) return redirectTo("/login?next=/matches");
  const context = await loadTeamContext(supabase);
  if (!context || context.role !== "coach") return redirectTo("/access-denied");
  return redirectTo(isUuid(id) ? `/matches/${id}/week` : "/matches");
}
