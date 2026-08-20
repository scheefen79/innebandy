import { describe, expect, it, vi } from "vitest";
import { createMatch, type MatchRepository, type StoredMatch } from "./create-match";
import type { MatchInput } from "./match-validation";

const input: MatchInput = {
  opponent: "Täby FC", startsAt: "2026-09-10T16:30:00.000Z", location: null,
  targetPlayers: 8, requestId: "550e8400-e29b-41d4-a716-446655440000",
};
const stored: StoredMatch = { ...input, id: "match-1" };

function repository(overrides: Partial<MatchRepository> = {}): MatchRepository {
  return {
    insert: vi.fn().mockResolvedValue({ duplicate: false, match: stored }),
    findByRequestId: vi.fn().mockResolvedValue(null), ...overrides,
  };
}

describe("createMatch", () => {
  it("returns a newly inserted match", async () => {
    await expect(createMatch(repository(), input)).resolves.toEqual({ ok: true, id: "match-1", replayed: false });
  });

  it("returns the first match for an identical retry", async () => {
    const repo = repository({ insert: vi.fn().mockResolvedValue({ duplicate: true }), findByRequestId: vi.fn().mockResolvedValue({ ...stored, startsAt: "2026-09-10 16:30:00+00:00" }) });
    await expect(createMatch(repo, input)).resolves.toEqual({ ok: true, id: "match-1", replayed: true });
  });

  it("converges parallel identical attempts to one match id", async () => {
    let saved: StoredMatch | null = null;
    const repo = repository({
      insert: vi.fn(async (candidate: MatchInput) => {
        if (saved) return { duplicate: true };
        saved = { ...candidate, id: "match-1" };
        return { duplicate: false, match: saved };
      }),
      findByRequestId: vi.fn(async () => saved),
    });
    const results = await Promise.all([createMatch(repo, input), createMatch(repo, input)]);
    expect(results.every((result) => result.ok && result.id === "match-1")).toBe(true);
  });

  it("rejects a reused request id with a changed normalized payload", async () => {
    const repo = repository({ insert: vi.fn().mockResolvedValue({ duplicate: true }), findByRequestId: vi.fn().mockResolvedValue({ ...stored, opponent: "Annat lag" }) });
    await expect(createMatch(repo, input)).resolves.toEqual({ ok: false, error: "REQUEST_CONFLICT" });
  });
});
