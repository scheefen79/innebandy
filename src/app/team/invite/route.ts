import { NextRequest, NextResponse } from "next/server";
import { inviteTeamMember, validateInviteInput } from "@/features/team-members/team-member-management";
import { loadTeamContext } from "@/lib/auth/team-context";
import { getVerifiedUserId } from "@/lib/auth/verified-user";
import { createAdminClient } from "@/lib/supabase/admin";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";

export async function POST(request: NextRequest) {
  const { applyAuthState, supabase } = createRouteHandlerClient(request);
  const go = (path: string) => applyAuthState(NextResponse.redirect(new URL(path, request.url), 303));
  const userId = await getVerifiedUserId();
  if (!userId) return go("/login?next=/team");
  const context = await loadTeamContext(supabase);
  if (!context || context.role !== "coach") return go("/access-denied");

  const form = await request.formData();
  const validated = validateInviteInput({ email: String(form.get("email") ?? ""), role: String(form.get("role") ?? "") });
  if (!validated.ok) return go(`/team?inviteError=invalid`);

  const result = await inviteTeamMember(createAdminClient(), {
    actorUserId: userId,
    teamId: context.teamId,
    email: validated.value.email,
    role: validated.value.role,
    redirectTo: new URL("/auth/set-password", request.url).toString(),
  });

  if (result.status === "ok") return go("/team?change=invited");
  return go(`/team?inviteError=${result.status}`);
}
