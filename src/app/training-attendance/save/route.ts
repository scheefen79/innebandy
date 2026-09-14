import { NextRequest, NextResponse } from "next/server";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createAdminClient } from "@/lib/supabase/admin";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";
import { saveTrainingAttendance } from "@/features/trainings/training-attendance";

const isUuid = (value: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);

export async function POST(request: NextRequest) {
  const { applyAuthState, supabase } = createRouteHandlerClient(request);
  const go = (path: string) => applyAuthState(NextResponse.redirect(new URL(path, request.url), 303));
  const userId = await getVerifiedUserId();
  if (!userId) return go("/login?next=/training-attendance");
  const context = await loadTeamContext(supabase);
  if (!context) return go("/access-denied");
  const form = await request.formData();
  const trainingId = String(form.get("training_id") ?? "");
  const status = String(form.get("status") ?? "");
  if (!isUuid(trainingId) || (status !== "coming" && status !== "absent")) return go("/training-attendance?change=invalid");
  const result = await saveTrainingAttendance(createAdminClient(), { actorUserId: userId, teamId: context.teamId, seasonId: context.seasonId, trainingId, status });
  return go(result === "ok" ? "/training-attendance?change=saved" : "/training-attendance?change=invalid");
}
