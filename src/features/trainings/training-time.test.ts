import {expect,it} from "vitest";import {formatTrainingDate,formatTrainingTime} from "./training-time";
it("formats summer and winter sessions in Stockholm time",()=>{expect(formatTrainingTime("2026-09-05T08:00:00Z","2026-09-05T09:00:00Z")).toContain("10:00–11:00");expect(formatTrainingTime("2026-11-02T15:15:00Z","2026-11-02T16:30:00Z")).toContain("16:15–17:30")});
it("formats the overview date without a time",()=>{expect(formatTrainingDate("2026-09-05T08:00:00Z")).toMatch(/lördag.*5 september/i);});
