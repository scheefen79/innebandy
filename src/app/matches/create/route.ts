import { NextRequest, NextResponse } from "next/server";
import { createMatch } from "@/features/matches/create-match";
import { DEFAULT_TARGET_PLAYERS } from "@/features/matches/match-defaults";
import { validateMatchInput } from "@/features/matches/match-validation";
import { createSupabaseMatchRepository } from "@/features/matches/supabase-match-repository";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";

export const dynamic = "force-dynamic";

function redirectTo(request: NextRequest, path: string) {
  return NextResponse.redirect(new URL(path, request.url), 303);
}

export async function POST(request: NextRequest) {
  const { applyAuthState, supabase } = createRouteHandlerClient(request);
  const userId = await getVerifiedUserId();
  if (!userId) return applyAuthState(redirectTo(request, "/login?next=/matches/new"));
  const context = await loadTeamContext(supabase);
  if (!context || context.role !== "coach") return applyAuthState(redirectTo(request, "/access-denied"));

  const formData = await request.formData();
  const values = Object.fromEntries(
    ["opponent", "date", "time", "location", "target_players", "request_id"]
      .map((key) => [key, String(formData.get(key) ?? "")]),
  );
  const validated = validateMatchInput(values, DEFAULT_TARGET_PLAYERS);
  if (!validated.ok) {
    return applyAuthState(redirectTo(request, `/matches/new?error=${encodeURIComponent(validated.error)}`));
  }

  const repository = createSupabaseMatchRepository(supabase, context.teamId, context.seasonId);
  const result = await createMatch(repository, validated.value);
  if (!result.ok) return applyAuthState(redirectTo(request, "/matches/new?error=conflict"));
  return applyAuthState(redirectTo(request, `/matches/${result.id}`));
}
