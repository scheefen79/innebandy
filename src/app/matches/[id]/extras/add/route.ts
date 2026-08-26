import { NextRequest, NextResponse } from "next/server";
import { isUuid } from "@/features/matches/match-validation";
import { mutateExtraSubstitute } from "@/features/selections/extra-substitute";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createAdminClient } from "@/lib/supabase/admin";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { applyAuthState, supabase } = createRouteHandlerClient(request);
  const redirectTo = (path: string) => applyAuthState(NextResponse.redirect(new URL(path, request.url), 303));
  const userId = await getVerifiedUserId();
  if (!userId) return redirectTo(`/login?next=${encodeURIComponent(`/matches/${id}`)}`);
  const context = await loadTeamContext(supabase);
  if (!context) return redirectTo("/access-denied");
  const form = await request.formData();
  const playerId = String(form.get("playerId") ?? "");
  const fingerprint = String(form.get("fingerprint") ?? "");
  if (![id, playerId].every(isUuid) || !/^[a-f0-9]{32}$/.test(fingerprint)) return redirectTo(`/matches/${id}/extras?error=invalid`);
  const result = await mutateExtraSubstitute(createAdminClient(), "add_extra_substitute", {
    actorUserId: userId, teamId: context.teamId, seasonId: context.seasonId,
    matchId: id, playerId, fingerprint,
  });
  if (result !== "ok") return redirectTo(`/matches/${id}/extras?error=${result}`);
  return redirectTo(`/matches/${id}?extra=added`);
}
