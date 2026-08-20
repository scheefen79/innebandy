import type { SupabaseClient } from "@supabase/supabase-js";
import { loadAllocationPreview } from "./allocation-preview";

export type SaveAllocationResult =
  | { ok: true; savedCount: number }
  | { ok: false; error: "ALLOCATION_ERROR" | "STALE_PREVIEW" };

export async function saveAllocation(
  userSupabase: SupabaseClient,
  adminSupabase: SupabaseClient,
  actorUserId: string,
  teamId: string,
  seasonId: string,
  boundary: string,
  expectedFingerprint: string,
): Promise<SaveAllocationResult> {
  const current = await loadAllocationPreview(userSupabase, teamId, seasonId, boundary);
  if (!current.ok) return { ok: false, error: "ALLOCATION_ERROR" };
  if (current.preview.fingerprint !== expectedFingerprint) return { ok: false, error: "STALE_PREVIEW" };

  const { data, error } = await adminSupabase.rpc("save_regular_allocation", {
    actor_user_id: actorUserId,
    target_team_id: teamId,
    target_season_id: seasonId,
    boundary,
    expected_fingerprint: expectedFingerprint,
    allocations: current.preview.allocations,
  });
  if (error?.message?.includes("STALE_PREVIEW")) return { ok: false, error: "STALE_PREVIEW" };
  if (error) throw new Error("Det gick inte att spara fördelningen.");
  return { ok: true, savedCount: Number(data) };
}
