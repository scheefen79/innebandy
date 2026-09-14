import type { SupabaseClient } from "@supabase/supabase-js";
import type { TrainingStatus } from "./training-plans";

export type TrainingAttendanceStatus = "coming" | "absent";
export type TrainingAttendanceResponse = { userId: string; name: string; status: TrainingAttendanceStatus };
export type TrainingAttendance = { id: string; startsAt: string; endsAt: string; themeBlock: number; focus: string; status: TrainingStatus; responses: TrainingAttendanceResponse[] };

const statuses = new Set<TrainingAttendanceStatus>(["coming", "absent"]);
const trainingStatuses = new Set<TrainingStatus>(["draft", "planned", "completed"]);

export async function loadTrainingAttendance(supabase: SupabaseClient, teamId: string, seasonId: string): Promise<TrainingAttendance[]> {
  const { data, error } = await supabase.rpc("get_training_attendance", { target_team_id: teamId, target_season_id: seasonId });
  if (error || !Array.isArray(data)) throw new Error("Det gick inte att hämta tränarnärvaron.");
  return data.map((value) => {
    const row = value as Record<string, unknown>;
    const responses = Array.isArray(row.responses) ? row.responses.map((response) => {
      const parsed = response as Record<string, unknown>;
      if (typeof parsed.userId !== "string" || typeof parsed.name !== "string" || !statuses.has(parsed.status as TrainingAttendanceStatus)) throw new Error("Tränarnärvaron är ogiltig.");
      return { userId: parsed.userId, name: parsed.name, status: parsed.status as TrainingAttendanceStatus };
    }) : null;
    if (typeof row.id !== "string" || typeof row.startsAt !== "string" || typeof row.endsAt !== "string" || !Number.isInteger(row.themeBlock) || typeof row.focus !== "string" || !trainingStatuses.has(row.status as TrainingStatus) || !responses || Number.isNaN(Date.parse(row.startsAt)) || Number.isNaN(Date.parse(row.endsAt))) throw new Error("Tränarnärvaron är ogiltig.");
    return { id: row.id, startsAt: row.startsAt, endsAt: row.endsAt, themeBlock: Number(row.themeBlock), focus: row.focus, status: row.status as TrainingStatus, responses };
  });
}

export async function saveTrainingAttendance(admin: SupabaseClient, input: { actorUserId: string; teamId: string; seasonId: string; trainingId: string; status: TrainingAttendanceStatus }) {
  const { error } = await admin.rpc("save_training_attendance", { actor_user_id: input.actorUserId, target_team_id: input.teamId, target_season_id: input.seasonId, target_training_id: input.trainingId, requested_status: input.status });
  if (!error) return "ok" as const;
  if (error.message.includes("TRAINING_COMPLETED") || error.message.includes("TRAINING_NOT_AVAILABLE")) return "invalid" as const;
  throw new Error("Det gick inte att spara ditt svar.");
}

export async function cancelTrainingSession(admin: SupabaseClient, input: { actorUserId: string; teamId: string; seasonId: string; trainingId: string }) {
 const { error } = await admin.rpc("cancel_training_session", { actor_user_id: input.actorUserId, target_team_id: input.teamId, target_season_id: input.seasonId, target_training_id: input.trainingId });
 if (!error) return "ok" as const;
 if (error.message.includes("TRAINING_COMPLETED") || error.message.includes("TRAINING_CANCELLED") || error.message.includes("TRAINING_PAST") || error.message.includes("TRAINING_NOT_AVAILABLE")) return "invalid" as const;
 throw new Error("Det gick inte att ställa in träningen.");
}

export const trainingAttendanceStatusText = (status: TrainingAttendanceStatus) => status === "coming" ? "Kommer" : "Frånvarande";
