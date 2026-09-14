import { NextRequest } from "next/server";
import { beforeEach, expect, it, vi } from "vitest";

const save = vi.hoisted(() => vi.fn().mockResolvedValue("ok"));
vi.mock("@/lib/supabase/route-handler", () => ({ createRouteHandlerClient: () => ({ applyAuthState: (response: Response) => response, supabase: {} }) }));
vi.mock("@/lib/auth/verified-user", () => ({ getVerifiedUserId: async () => "member" }));
vi.mock("@/lib/auth/team-context", () => ({ loadTeamContext: async () => ({ teamId: "team", seasonId: "season", seasonName: "S", role: "viewer" }) }));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient: () => ({ kind: "admin" }) }));
vi.mock("@/features/trainings/training-attendance", () => ({ saveTrainingAttendance: save }));
import { POST } from "./route";

const request = (status = "coming") => new NextRequest("https://app.example/training-attendance/save", { method: "POST", body: new URLSearchParams({ training_id: "e4000000-0000-4000-8000-000000000001", status }) });
beforeEach(() => save.mockReset().mockResolvedValue("ok"));
it("saves only the authenticated member's response through the server boundary", async () => {
  const response = await POST(request());
  expect(save).toHaveBeenCalledWith({ kind: "admin" }, expect.objectContaining({ actorUserId: "member", status: "coming" }));
  expect(response.headers.get("location")).toBe("https://app.example/training-attendance?change=saved");
});
it("rejects an invalid status before saving", async () => {
  const response = await POST(request("maybe"));
  expect(save).not.toHaveBeenCalled();
  expect(response.headers.get("location")).toContain("change=invalid");
});
