import type { SupabaseClient } from "@supabase/supabase-js";

type AdjustmentEnvelope = { fingerprint?: unknown; source?: unknown };

export async function loadManualAdjustmentFingerprint(
  supabase: SupabaseClient,
  teamId: string,
  seasonId: string,
  matchId: string,
): Promise<string> {
  const { data, error } = await supabase.rpc("get_manual_adjustment_source", {
    target_team_id: teamId,
    target_season_id: seasonId,
    target_match_id: matchId,
  });
  if (error) throw new Error("Det gick inte att läsa bytesunderlaget.");
  const envelope = data as AdjustmentEnvelope | null;
  if (!envelope || typeof envelope.fingerprint !== "string" || !envelope.source) {
    throw new Error("Bytesunderlaget är ogiltigt.");
  }
  return envelope.fingerprint;
}

type AdjustmentAction = "create_manual_regular_adjustment" | "restore_manual_regular_adjustment";

export async function mutateManualAdjustment(
  adminSupabase: SupabaseClient,
  action: AdjustmentAction,
  input: {
    actorUserId: string;
    teamId: string;
    seasonId: string;
    matchId: string;
    outgoingPlayerId: string;
    incomingPlayerId: string;
    fingerprint: string;
  },
): Promise<"ok" | "stale" | "invalid"> {
  const { error } = await adminSupabase.rpc(action, {
    actor_user_id: input.actorUserId,
    target_team_id: input.teamId,
    target_season_id: input.seasonId,
    target_match_id: input.matchId,
    outgoing_player_id: input.outgoingPlayerId,
    incoming_player_id: input.incomingPlayerId,
    expected_fingerprint: input.fingerprint,
  });
  if (!error) return "ok";
  if (error.message.includes("STALE_SELECTION")) return "stale";
  if (error.message.includes("INVALID_ADJUSTMENT") || error.message.includes("MATCH_NOT_AVAILABLE")) return "invalid";
  throw new Error("Det gick inte att spara det manuella bytet.");
}

export const MAX_BATCH_SIZE = 20;

export type AdjustmentPair = { outgoingPlayerId: string; incomingPlayerId: string };

/** Reads `outgoingPlayerId` (repeated) and one `incoming:<outgoingId>` field per outgoing player. */
export function parseAdjustmentPairs(
  form: Pick<FormData, "getAll" | "get">,
  isValidId: (value: string) => boolean,
): AdjustmentPair[] | null {
  const outgoing = form.getAll("outgoingPlayerId").map(String);
  if (outgoing.length < 1 || outgoing.length > MAX_BATCH_SIZE) return null;
  const pairs = outgoing.map((outgoingPlayerId) => ({ outgoingPlayerId, incomingPlayerId: String(form.get(`incoming:${outgoingPlayerId}`) ?? "") }));
  const ids = pairs.flatMap((pair) => [pair.outgoingPlayerId, pair.incomingPlayerId]);
  if (!ids.every(isValidId) || new Set(ids).size !== ids.length) return null;
  return pairs;
}

export async function mutateManualAdjustments(
  adminSupabase: SupabaseClient,
  input: {
    actorUserId: string;
    teamId: string;
    seasonId: string;
    matchId: string;
    pairs: AdjustmentPair[];
    fingerprint: string;
  },
): Promise<"ok" | "stale" | "invalid"> {
  const { error } = await adminSupabase.rpc("create_manual_regular_adjustments", {
    actor_user_id: input.actorUserId,
    target_team_id: input.teamId,
    target_season_id: input.seasonId,
    target_match_id: input.matchId,
    requested_adjustments: input.pairs,
    expected_fingerprint: input.fingerprint,
  });
  if (!error) return "ok";
  if (error.message.includes("STALE_SELECTION")) return "stale";
  if (error.message.includes("INVALID_ADJUSTMENT") || error.message.includes("MATCH_NOT_AVAILABLE")) return "invalid";
  throw new Error("Det gick inte att spara de manuella byten.");
}
