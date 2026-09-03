import { NextRequest, NextResponse } from "next/server";
import { isUuid } from "@/features/matches/match-validation";
import { deactivateTeamMember } from "@/features/team-members/team-member-management";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createAdminClient } from "@/lib/supabase/admin";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";

export async function POST(request: NextRequest, { params }: { params: Promise<{ userId: string }> }) {
  const { userId: targetUserId } = await params;
  const { applyAuthState, supabase } = createRouteHandlerClient(request);
  const go = (path: string) => applyAuthState(NextResponse.redirect(new URL(path, request.url), 303));
  const userId = await getVerifiedUserId();
  if (!userId) return go("/login?next=/team");
  const context = await loadTeamContext(supabase);
  if (!context || context.role !== "coach") return go("/access-denied");

  const form = await request.formData();
  const fingerprint = String(form.get("fingerprint") ?? "");
  if (!isUuid(targetUserId) || !/^[a-f0-9]{32}$/.test(fingerprint)) return go("/team?mutationError=invalid");

  const result = await deactivateTeamMember(createAdminClient(), { actorUserId: userId, teamId: context.teamId, targetUserId, fingerprint });
  if (result !== "ok") return go(`/team?mutationError=${result}`);
  return go("/team?change=deactivated");
}
