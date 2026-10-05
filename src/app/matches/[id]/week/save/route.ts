import { NextRequest, NextResponse } from "next/server";
import { isUuid } from "@/features/matches/match-validation";
import { parseWorkflowCommand, saveMatchWorkflow } from "@/features/match-workflow/workflow";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createAdminClient } from "@/lib/supabase/admin";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";
export const dynamic = "force-dynamic";
export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { supabase, applyAuthState } = createRouteHandlerClient(request);
  const redirectTo = (path: string) => applyAuthState(NextResponse.redirect(new URL(path, request.url), 303));
  const actor = await getVerifiedUserId();
  if (!actor) return redirectTo("/login?next=/matches");
  const context = await loadTeamContext(supabase);
  if (!context || context.role !== "coach") return redirectTo("/access-denied");
  if (!isUuid(id)) return redirectTo("/matches");
  const command = parseWorkflowCommand(await request.formData());
  if (!command) return redirectTo(`/matches/${id}/week?error=INVALID_WORKFLOW`);
  const error = await saveMatchWorkflow(createAdminClient(), actor, context.teamId, context.seasonId, id, command);
  return redirectTo(`/matches/${id}/week?${error ? `error=${error}` : "saved=1"}`);
}
