import type { SupabaseClient } from "@supabase/supabase-js";
import { isUuid } from "@/features/matches/match-validation";

export type PlayerInput = { firstName: string; lastName: string | null; level: 1 | 2 | 3 };

export function validatePlayerInput(values: Record<string, string>): { ok: true; value: PlayerInput } | { ok: false; error: string } {
  const firstName = values.first_name?.trim();
  const lastName = values.last_name?.trim() || null;
  const level = Number(values.level);
  if (!firstName || firstName.length > 100) return { ok: false, error: "Ange ett förnamn med högst 100 tecken." };
  if (lastName && lastName.length > 100) return { ok: false, error: "Efternamnet får vara högst 100 tecken." };
  if (level !== 1 && level !== 2 && level !== 3) return { ok: false, error: "Välj nivå 1, 2 eller 3." };
  return { ok: true, value: { firstName, lastName, level } };
}

export async function createPlayer(admin: SupabaseClient, input: PlayerInput & { actorUserId: string; teamId: string; seasonId: string; requestId: string }) {
  if (!isUuid(input.requestId)) return { status: "invalid" as const };
  const { data, error } = await admin.rpc("create_player", { actor_user_id: input.actorUserId, target_team_id: input.teamId, target_season_id: input.seasonId, requested_first_name: input.firstName, requested_last_name: input.lastName ?? "", requested_level: input.level, request_id: input.requestId });
  if (!error && typeof data === "string") return { status: "ok" as const, playerId: data };
  if (error?.message.includes("REQUEST_CONFLICT") || error?.message.includes("INVALID_PLAYER") || error?.message.includes("PLAYER_NOT_AVAILABLE")) return { status: "invalid" as const };
  throw new Error("Det gick inte att skapa spelaren.");
}

export async function mutatePlayer(admin: SupabaseClient, action: "update_player" | "deactivate_player", input: PlayerInput & { actorUserId: string; teamId: string; seasonId: string; playerId: string; fingerprint: string }) {
  const args = { actor_user_id: input.actorUserId, target_team_id: input.teamId, target_season_id: input.seasonId, target_player_id: input.playerId, expected_fingerprint: input.fingerprint } as Record<string, unknown>;
  if (action === "update_player") Object.assign(args, { requested_first_name: input.firstName, requested_last_name: input.lastName ?? "", requested_level: input.level });
  const { error } = await admin.rpc(action, args);
  if (!error) return "ok" as const;
  if (error.message.includes("STALE_PLAYER")) return "stale" as const;
  if (error.message.includes("PLAYER_HAS_PLANNED_DECISIONS")) return "blocked" as const;
  if (error.message.includes("INVALID_PLAYER") || error.message.includes("PLAYER_NOT_AVAILABLE")) return "invalid" as const;
  throw new Error("Det gick inte att uppdatera spelaren.");
}
