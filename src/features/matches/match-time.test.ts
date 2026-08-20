import { describe, expect, it } from "vitest";
import { stockholmLocalToUtc } from "./match-time";

describe("stockholmLocalToUtc", () => {
  it("converts Swedish summer and winter times to UTC", () => {
    expect(stockholmLocalToUtc("2026-08-20", "18:30")).toEqual({ ok: true, value: "2026-08-20T16:30:00.000Z" });
    expect(stockholmLocalToUtc("2026-12-20", "18:30")).toEqual({ ok: true, value: "2026-12-20T17:30:00.000Z" });
  });

  it("rejects nonexistent and ambiguous DST times", () => {
    expect(stockholmLocalToUtc("2026-03-29", "02:30")).toEqual({ ok: false, reason: "nonexistent" });
    expect(stockholmLocalToUtc("2026-10-25", "02:30")).toEqual({ ok: false, reason: "ambiguous" });
  });
});
