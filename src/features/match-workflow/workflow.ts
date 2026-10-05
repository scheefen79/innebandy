import type { SupabaseClient } from "@supabase/supabase-js";
import { isUuid } from "@/features/matches/match-validation";
import { recommendExtraPlayers } from "@/domain/allocation/extra-recommendation";

export const responseLabels = {
  uninvited: "Ej kallad", pending: "Inväntar svar", accepted: "Tackat ja",
  declined: "Tackat nej", withdrawn: "Kallelse indragen",
} as const;
export type MatchResponse = keyof typeof responseLabels;
export type MatchPhase = "planning" | "week" | "locked" | "legacy";
export type MatchTotals = { historyComplete?: boolean; offeredRegular: number; plannedRegular: number; plannedExtra: number; completedRegular: number; completedExtra: number; lastExtraAt: string | null };
export type WorkflowPlayer = {
  id: string; name: string; level: number; active: boolean; rotationOrder: number;
  inPlan: boolean; offeredRegular: boolean; response: MatchResponse; played: boolean;
  participationType: "regular" | "extra" | null; totals: MatchTotals;
};
export type MatchWorkflow = {
  phase: MatchPhase; revision: number; historyRequired: boolean;
  status: "upcoming" | "completed" | "cancelled"; startsAt: string;
  players: WorkflowPlayer[];
  events: { action: string; reason: string | null; at: string; revision: number }[];
};
export type WorkflowAction = "start" | "responses" | "lock" | "correct" | "history" | "cancel";
export type WorkflowCommand = { action: WorkflowAction; revision: number; requestId: string; changes: unknown[]; reason: string | null };

export function summarizeResponses(players: Pick<WorkflowPlayer, "response">[]) {
  const accepted = players.filter(p => p.response === "accepted").length;
  const pending = players.filter(p => p.response === "pending").length;
  return { accepted, pending, reserved: accepted + pending, remaining: 10 - accepted - pending };
}

export function rankExtraCandidates(players: WorkflowPlayer[]) {
  const candidates = players.filter(p => p.active && !p.inPlan && p.response === "uninvited");
  const result = recommendExtraPlayers({ eligibleCandidates: candidates.map(p => ({
    id: p.id, rotationOrder: p.rotationOrder, completedExtraCount: p.totals.completedExtra,
    regularCount: p.totals.offeredRegular,
    lastCompletedExtraAt: p.totals.lastExtraAt ? new Date(p.totals.lastExtraAt).toISOString() : null,
  })) });
  if (!result.ok) throw new Error("Historiken för extra inhopp är ogiltig.");
  return result.candidateIds;
}

export function parseWorkflowCommand(form: FormData): WorkflowCommand | null {
  const action = String(form.get("action") ?? "") as WorkflowAction;
  const rawRevision = String(form.get("revision") ?? "");
  const revision = Number(rawRevision);
  const requestId = String(form.get("requestId") ?? "");
  const reason = String(form.get("reason") ?? "").trim() || null;
  if (!["start", "responses", "lock", "correct", "history", "cancel"].includes(action) || !/^\d+$/.test(rawRevision) || !Number.isSafeInteger(revision) || !isUuid(requestId)) return null;
  let changes: unknown[] = [];
  if (action === "responses") {
    const ids = form.getAll("playerId").map(String);
    if (new Set(ids).size !== ids.length || !ids.every(isUuid)) return null;
    for (const playerId of ids) {
      const response = String(form.get(`response:${playerId}`) ?? "");
      if (!["pending", "accepted", "declined", "withdrawn"].includes(response)) return null;
      changes.push({ playerId, response });
    }
  } else if (["lock", "correct", "history"].includes(action)) {
    if (action === "history" && form.get("historyConfirmed") !== "on") return null;
    const ids = form.getAll("selectedPlayerId").map(String);
    if (new Set(ids).size !== ids.length || !ids.every(isUuid)) return null;
    if (action !== "history" && (ids.length < 1 || ids.length > 10)) return null;
    if (action === "correct" && (!reason || reason.length > 500)) return null;
    changes = action === "history" ? ids.map(playerId => ({ playerId, response: "withdrawn" })) : ids;
  }
  return { action, revision, requestId, changes, reason };
}

export async function loadMatchWorkflow(supabase: SupabaseClient, teamId: string, seasonId: string, matchId: string): Promise<MatchWorkflow> {
  const { data, error } = await supabase.rpc("get_match_workflow", { target_team_id: teamId, target_season_id: seasonId, target_match_id: matchId });
  if (error || !data || !["planning", "week", "locked", "legacy"].includes(data.phase) || !Number.isInteger(data.revision) || !Array.isArray(data.players) || !Array.isArray(data.events)) throw new Error("Det gick inte att hämta matchveckan.");
  return data as MatchWorkflow;
}

export const workflowErrorText: Record<string, string> = {
  STALE_WORKFLOW: "Matchen ändrades av någon annan. Kontrollera aktuella uppgifter och välj dina ändringar igen.",
  ROSTER_CAPACITY: "Högst tio spelare kan ha tackat ja eller invänta svar tillsammans.",
  UNRESOLVED_RESPONSES: "Registrera svar för alla obesvarade kallelser innan deltagandet låses.",
  INVALID_WORKFLOW: "Ändringen kunde inte sparas. Kontrollera valen och matchens status.",
  REQUEST_CONFLICT: "Sparningen har redan använts med andra uppgifter. Ladda om sidan och försök igen.",
  MATCH_NOT_AVAILABLE: "Matchen är inte längre tillgänglig för denna ändring.",
};

export async function saveMatchWorkflow(supabase: SupabaseClient, actorUserId: string, teamId: string, seasonId: string, matchId: string, command: WorkflowCommand): Promise<string | null> {
  const { error } = await supabase.rpc("save_match_workflow", {
    actor_user_id: actorUserId, target_team_id: teamId, target_season_id: seasonId, target_match_id: matchId,
    expected_revision: command.revision, request_id: command.requestId,
    requested_action: command.action, changes: command.changes, reason: command.reason,
  });
  if (!error) return null;
  const known = Object.keys(workflowErrorText).find(code => error.message.includes(code));
  if (known) return known;
  throw new Error("Det gick inte att spara matchen.");
}
