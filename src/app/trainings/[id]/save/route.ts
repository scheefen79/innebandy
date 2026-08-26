import { NextRequest, NextResponse } from "next/server";
import { loadTeamContext } from "@/lib/auth/team-context";
import { createAdminClient } from "@/lib/supabase/admin";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";
import { saveTrainingPlan, validateTrainingPayload } from "@/features/trainings/training-plans";

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { applyAuthState, supabase } = createRouteHandlerClient(request);
  const go = (path: string) => applyAuthState(NextResponse.redirect(new URL(path, request.url), 303));
  const { data } = await supabase.auth.getClaims();
  if (!data?.claims?.sub) return go(`/login?next=${encodeURIComponent(`/trainings/${id}/edit`)}`);
  const context = await loadTeamContext(supabase);
  if (!context) return go("/access-denied");

  const form = await request.formData();
  const validated = validateTrainingPayload({
    focus: String(form.get("focus") ?? ""),
    keyMessage: String(form.get("key_message") ?? ""),
    coachNotes: String(form.get("coach_notes") ?? ""),
    status: String(form.get("status") ?? ""),
    items: String(form.get("items") ?? ""),
  });
  const revision = Number(form.get("revision"));
  if (!validated.ok || !Number.isInteger(revision) || revision < 1) return go(`/trainings/${id}/edit?error=invalid`);

  const result = await saveTrainingPlan(createAdminClient(), {
    actorUserId: data.claims.sub,
    teamId: context.teamId,
    seasonId: context.seasonId,
    trainingId: id,
    revision,
    requestId: `${id}:${revision}`,
    ...validated.value,
  });
  if (result === "stale") return go(`/trainings/${id}?change=stale`);
  if (result === "invalid") return go(`/trainings/${id}/edit?error=invalid`);
  return go(`/trainings/${id}?change=saved`);
}
