import type { MatchInput } from "./match-validation";

export type StoredMatch = MatchInput & { id: string };
export type MatchRepository = {
  insert(input: MatchInput): Promise<{ match?: StoredMatch; duplicate: boolean }>;
  findByRequestId(requestId: string): Promise<StoredMatch | null>;
};
export type CreateMatchResult =
  | { ok: true; id: string; replayed: boolean }
  | { ok: false; error: "REQUEST_CONFLICT" };

function isSamePayload(a: MatchInput, b: StoredMatch) {
  return a.opponent === b.opponent && Date.parse(a.startsAt) === Date.parse(b.startsAt) &&
    a.location === b.location && a.targetPlayers === b.targetPlayers;
}

export async function createMatch(repository: MatchRepository, input: MatchInput): Promise<CreateMatchResult> {
  const inserted = await repository.insert(input);
  if (inserted.match) return { ok: true, id: inserted.match.id, replayed: false };
  if (inserted.duplicate) {
    const existing = await repository.findByRequestId(input.requestId);
    if (existing && isSamePayload(input, existing)) return { ok: true, id: existing.id, replayed: true };
  }
  return { ok: false, error: "REQUEST_CONFLICT" };
}
