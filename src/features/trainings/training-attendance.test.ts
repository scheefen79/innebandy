import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { loadTrainingAttendance, trainingAttendanceStatusText } from "./training-attendance";

describe("training attendance", () => {
  it("loads attendance responses for a training", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: [{ id: "t1", startsAt: "2026-09-05T08:00:00Z", endsAt: "2026-09-05T09:00:00Z", themeBlock: 1, focus: "Passning", status: "planned", responses: [{ userId: "u1", name: "anders", status: "coming" }] }], error: null });
    await expect(loadTrainingAttendance({ rpc } as unknown as SupabaseClient, "team", "season")).resolves.toMatchObject([{ id: "t1", responses: [{ status: "coming" }] }]);
  });

  it("rejects malformed responses and uses Swedish status text", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: [{ id: "t1", startsAt: "2026-09-05T08:00:00Z", endsAt: "2026-09-05T09:00:00Z", themeBlock: 1, focus: "Passning", status: "planned", responses: [{ userId: "u1", name: "anders", status: "maybe" }] }], error: null });
    await expect(loadTrainingAttendance({ rpc } as unknown as SupabaseClient, "team", "season")).rejects.toThrow("ogiltig");
    expect(trainingAttendanceStatusText("coming")).toBe("Kommer");
    expect(trainingAttendanceStatusText("absent")).toBe("Frånvarande");
  });
});
