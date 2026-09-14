import { NextRequest } from "next/server";
import { beforeEach, expect, it, vi } from "vitest";

const state = vi.hoisted(() => ({ role: "coach" }));
const cancel = vi.hoisted(() => vi.fn().mockResolvedValue("ok"));
vi.mock("@/lib/supabase/route-handler", () => ({ createRouteHandlerClient: () => ({ applyAuthState: (response: Response) => response, supabase: {} }) }));
vi.mock("@/lib/auth/verified-user", () => ({ getVerifiedUserId: async () => "coach" }));
vi.mock("@/lib/auth/team-context", () => ({ loadTeamContext: async () => ({ teamId: "team", seasonId: "season", seasonName: "S", role: state.role }) }));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient: () => ({ kind: "admin" }) }));
vi.mock("@/features/trainings/training-attendance", () => ({ cancelTrainingSession: cancel }));
import { POST } from "./route";

const request = () => new NextRequest("https://app.example/training-attendance/cancel", { method: "POST", body: new URLSearchParams({ training_id: "e4000000-0000-4000-8000-000000000001" }) });
beforeEach(() => { state.role = "coach"; cancel.mockReset().mockResolvedValue("ok"); });
it("lets a coach cancel a future training through the server boundary", async () => {
  const response = await POST(request());
  expect(cancel).toHaveBeenCalledWith({ kind: "admin" }, expect.objectContaining({ actorUserId: "coach", trainingId: "e4000000-0000-4000-8000-000000000001" }));
  expect(response.headers.get("location")).toBe("https://app.example/training-attendance?change=cancelled&open=e4000000-0000-4000-8000-000000000001");
});
it("does not allow a viewer to cancel a training", async () => {
  state.role = "viewer";
  const response = await POST(request());
  expect(cancel).not.toHaveBeenCalled();
  expect(response.headers.get("location")).toBe("https://app.example/access-denied");
});
