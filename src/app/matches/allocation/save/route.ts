import { NextRequest, NextResponse } from "next/server";
import { saveAllocation } from "@/features/selections/save-allocation";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";
import { createAdminClient } from "@/lib/supabase/admin";

export const dynamic = "force-dynamic";

function redirectTo(request: NextRequest, path: string) {
  return NextResponse.redirect(new URL(path, request.url), 303);
}

export async function POST(request: NextRequest) {
  const { applyAuthState, supabase } = createRouteHandlerClient(request);
  const userId = await getVerifiedUserId();
  if (!userId) return applyAuthState(redirectTo(request, "/login?next=/matches"));
  const context = await loadTeamContext(supabase);
  if (!context) return applyAuthState(redirectTo(request, "/access-denied"));

  const formData = await request.formData();
  const fingerprint = String(formData.get("fingerprint") ?? "");
  if (!/^[a-f0-9]{32}$/.test(fingerprint)) {
    return applyAuthState(redirectTo(request, "/matches/allocation/preview?error=stale"));
  }

  const boundary = new Date().toISOString();
  const result = await saveAllocation(
    supabase,
    createAdminClient(),
    userId,
    context.teamId,
    context.seasonId,
    boundary,
    fingerprint,
  );
  if (!result.ok) return applyAuthState(redirectTo(request, "/matches/allocation/preview?error=stale"));
  return applyAuthState(redirectTo(request, "/matches?allocation=saved"));
}
