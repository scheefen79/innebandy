import { NextRequest, NextResponse } from "next/server";
import { cancelTrainingSession } from "@/features/trainings/training-attendance";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createAdminClient } from "@/lib/supabase/admin";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";

const isUuid = (value: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);

export async function POST(request: NextRequest) {
  const { applyAuthState, supabase } = createRouteHandlerClient(request);
  const go = (path: string) => applyAuthState(NextResponse.redirect(new URL(path, request.url), 303));
  const userId = await getVerifiedUserId();
  if (!userId) return go("/login?next=/training-attendance");
  const context = await loadTeamContext(supabase);
  if (!context || context.role !== "coach") return go("/access-denied");
  const trainingId = String((await request.formData()).get("training_id") ?? "");
  if (!isUuid(trainingId)) return go("/training-attendance?change=cancel-invalid");
  const result = await cancelTrainingSession(createAdminClient(), { actorUserId: userId, teamId: context.teamId, seasonId: context.seasonId, trainingId });
  return go(result === "ok" ? `/training-attendance?change=cancelled&open=${encodeURIComponent(trainingId)}` : "/training-attendance?change=cancel-invalid");
}
