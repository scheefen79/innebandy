import { describe, expect, it } from "vitest";
import { getSafeNextPath } from "./safe-next-path";

describe("getSafeNextPath", () => {
  it.each([
    [null, "/"],
    ["", "/"],
    ["https://example.com", "/"],
    ["//example.com", "/"],
    ["/\\example.com", "/"],
    ["/%0a/example.com", "/%0a/example.com"],
    ["/spelare", "/spelare"],
    ["/?filter=active", "/?filter=active"],
    ["/spelare#aktiva", "/spelare#aktiva"],
  ])("maps %s to %s", (value, expected) => {
    expect(getSafeNextPath(value)).toBe(expected);
  });
});
