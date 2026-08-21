import { NextRequest, NextResponse } from "next/server";
import { isUuid } from "@/features/matches/match-validation";
import { mutateManualAdjustment } from "@/features/selections/manual-adjustment";
import { loadTeamContext } from "@/lib/auth/team-context";
import { createAdminClient } from "@/lib/supabase/admin";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { applyAuthState, supabase } = createRouteHandlerClient(request);
  const redirectTo = (path: string) => applyAuthState(NextResponse.redirect(new URL(path, request.url), 303));
  const { data } = await supabase.auth.getClaims();
  if (!data?.claims?.sub) return redirectTo(`/login?next=${encodeURIComponent(`/matches/${id}`)}`);
  const context = await loadTeamContext(supabase);
  if (!context) return redirectTo("/access-denied");
  const form = await request.formData();
  const outgoingPlayerId = String(form.get("outgoingPlayerId") ?? "");
  const incomingPlayerId = String(form.get("incomingPlayerId") ?? "");
  const fingerprint = String(form.get("fingerprint") ?? "");
  if (![id, outgoingPlayerId, incomingPlayerId].every(isUuid) || !/^[a-f0-9]{32}$/.test(fingerprint)) return redirectTo(`/matches/${id}/adjust?error=invalid`);
  const result = await mutateManualAdjustment(createAdminClient(), "create_manual_regular_adjustment", {
    actorUserId: data.claims.sub, teamId: context.teamId, seasonId: context.seasonId,
    matchId: id, outgoingPlayerId, incomingPlayerId, fingerprint,
  });
  if (result !== "ok") return redirectTo(`/matches/${id}/adjust?error=${result}`);
  return redirectTo(`/matches/${id}?adjustment=saved`);
}
