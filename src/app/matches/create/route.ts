import { NextRequest, NextResponse } from "next/server";
import { createMatch } from "@/features/matches/create-match";
import { validateMatchInput } from "@/features/matches/match-validation";
import { createSupabaseMatchRepository } from "@/features/matches/supabase-match-repository";
import { loadTeamContext } from "@/lib/auth/team-context";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";

export const dynamic = "force-dynamic";

function redirectTo(request: NextRequest, path: string) {
  return NextResponse.redirect(new URL(path, request.url), 303);
}

export async function POST(request: NextRequest) {
  const { applyAuthState, supabase } = createRouteHandlerClient(request);
  const { data } = await supabase.auth.getClaims();
  if (!data?.claims?.sub) return applyAuthState(redirectTo(request, "/login?next=/matches/new"));
  const context = await loadTeamContext(supabase);
  if (!context) return applyAuthState(redirectTo(request, "/access-denied"));

  const formData = await request.formData();
  const values = Object.fromEntries(
    ["opponent", "date", "time", "location", "target_players", "request_id"]
      .map((key) => [key, String(formData.get(key) ?? "")]),
  );
  const { count, error: countError } = await supabase.from("players")
    .select("id", { count: "exact", head: true })
    .eq("team_id", context.teamId).eq("season_id", context.seasonId).eq("is_active", true);
  if (countError) throw new Error("Det gick inte att räkna aktiva spelare.");

  const validated = validateMatchInput(values, count ? Math.ceil(count / 2) : null);
  if (!validated.ok) {
    return applyAuthState(redirectTo(request, `/matches/new?error=${encodeURIComponent(validated.error)}`));
  }

  const repository = createSupabaseMatchRepository(supabase, context.teamId, context.seasonId);
  const result = await createMatch(repository, validated.value);
  if (!result.ok) return applyAuthState(redirectTo(request, "/matches/new?error=conflict"));
  return applyAuthState(redirectTo(request, `/matches/${result.id}`));
}
