import type { SupabaseClient } from "@supabase/supabase-js";
import type { TeamRole } from "@/lib/auth/team-context";

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function validateInviteInput(values: { email: string; role: string }): { ok: true; value: { email: string; role: TeamRole } } | { ok: false; error: string } {
  const email = values.email?.trim().toLowerCase();
  if (!email || email.length > 254 || !emailPattern.test(email)) return { ok: false, error: "Ange en giltig e-postadress." };
  if (values.role !== "coach" && values.role !== "viewer") return { ok: false, error: "Välj en roll." };
  return { ok: true, value: { email, role: values.role } };
}

export type InviteResult =
  | { status: "ok"; userId: string }
  | { status: "already_active" }
  | { status: "already_inactive" }
  | { status: "unlinked_account" };

export async function inviteTeamMember(
  admin: SupabaseClient,
  input: { actorUserId: string; teamId: string; email: string; role: TeamRole; redirectTo: string },
): Promise<InviteResult> {
  const invite = await admin.auth.admin.inviteUserByEmail(input.email, { redirectTo: input.redirectTo });

  if (!invite.error && invite.data.user) {
    const { error } = await admin.rpc("upsert_team_member", {
      actor_user_id: input.actorUserId,
      target_team_id: input.teamId,
      target_user_id: invite.data.user.id,
      requested_role: input.role,
    });
    if (error) throw new Error("Det gick inte att koppla den inbjudna personen till laget.");
    return { status: "ok", userId: invite.data.user.id };
  }

  const alreadyRegistered = invite.error?.code === "email_exists" || invite.error?.status === 422;
  if (!alreadyRegistered) throw new Error("Det gick inte att skicka inbjudan.");

  const { data: members, error: listError } = await admin.rpc("get_team_member_list", { target_team_id: input.teamId });
  if (listError || !Array.isArray(members)) throw new Error("Det gick inte att skicka inbjudan.");
  const existing = (members as Record<string, unknown>[]).find((member) => member.email === input.email);
  if (!existing) return { status: "unlinked_account" };
  return existing.isActive ? { status: "already_active" } : { status: "already_inactive" };
}

export async function changeTeamMemberRole(admin: SupabaseClient, input: { actorUserId: string; teamId: string; targetUserId: string; role: TeamRole; fingerprint: string }) {
  const { error } = await admin.rpc("update_team_member_role", {
    actor_user_id: input.actorUserId,
    target_team_id: input.teamId,
    target_user_id: input.targetUserId,
    requested_role: input.role,
    expected_fingerprint: input.fingerprint,
  });
  return interpretMemberMutationError(error);
}

export async function deactivateTeamMember(admin: SupabaseClient, input: { actorUserId: string; teamId: string; targetUserId: string; fingerprint: string }) {
  const { error } = await admin.rpc("deactivate_team_member", {
    actor_user_id: input.actorUserId,
    target_team_id: input.teamId,
    target_user_id: input.targetUserId,
    expected_fingerprint: input.fingerprint,
  });
  return interpretMemberMutationError(error);
}

export async function reactivateTeamMember(admin: SupabaseClient, input: { actorUserId: string; teamId: string; targetUserId: string; fingerprint: string }) {
  const { error } = await admin.rpc("reactivate_team_member", {
    actor_user_id: input.actorUserId,
    target_team_id: input.teamId,
    target_user_id: input.targetUserId,
    expected_fingerprint: input.fingerprint,
  });
  return interpretMemberMutationError(error);
}

function interpretMemberMutationError(error: { message: string } | null) {
  if (!error) return "ok" as const;
  if (error.message.includes("STALE_MEMBER")) return "stale" as const;
  if (error.message.includes("LAST_ACTIVE_COACH")) return "last_active_coach" as const;
  if (error.message.includes("MEMBER_NOT_AVAILABLE")) return "invalid" as const;
  throw new Error("Det gick inte att uppdatera medlemmen.");
}
