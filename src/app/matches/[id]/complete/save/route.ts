import { NextRequest, NextResponse } from "next/server";
import { isUuid } from "@/features/matches/match-validation";
import { buildParticipation, completeMatch } from "@/features/selections/match-completion";
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
  if (!context || context.role !== "coach") return redirectTo("/access-denied");
  const form = await request.formData();
  const fingerprint = String(form.get("fingerprint") ?? "");
  const playerIds = form.getAll("playerId").map(String);
  const playedPlayerIds = form.getAll("playedPlayerId").map(String);
  const participation = buildParticipation(playerIds, playedPlayerIds);
  if (!isUuid(id) || !/^[a-f0-9]{32}$/.test(fingerprint) || playerIds.length === 0 || !playerIds.every(isUuid) || !playedPlayerIds.every(isUuid) || !participation) return redirectTo(`/matches/${id}/complete?error=invalid`);
  const result = await completeMatch(createAdminClient(), { actorUserId: userId, teamId: context.teamId, seasonId: context.seasonId, matchId: id, fingerprint, participation });
  if (result === "completed") return redirectTo(`/matches/${id}?completion=conflict`);
  if (result !== "ok") return redirectTo(`/matches/${id}/complete?error=${result}`);
  return redirectTo(`/matches/${id}?completion=saved`);
}
