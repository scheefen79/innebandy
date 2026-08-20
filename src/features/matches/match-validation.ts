import { stockholmLocalToUtc } from "./match-time";

export type MatchInput = {
  opponent: string; startsAt: string; location: string | null;
  targetPlayers: number; requestId: string;
};

export type MatchValidationResult =
  | { ok: true; value: MatchInput }
  | { ok: false; error: string };

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function isUuid(value: string) {
  return uuidPattern.test(value);
}

export function validateMatchInput(values: Record<string, string>, defaultTarget: number | null): MatchValidationResult {
  const opponent = values.opponent?.trim();
  const location = values.location?.trim() || null;
  const requestId = values.request_id?.trim();

  if (!opponent || opponent.length > 100) return { ok: false, error: "Ange ett motståndarlag med högst 100 tecken." };
  if (location && location.length > 200) return { ok: false, error: "Platsen får vara högst 200 tecken." };
  if (!isUuid(requestId)) return { ok: false, error: "Formuläret har gått ut. Ladda om sidan och försök igen." };

  const parsedTarget = values.target_players?.trim() ? Number(values.target_players) : defaultTarget;
  if (!Number.isInteger(parsedTarget) || parsedTarget === null || parsedTarget <= 0) {
    return { ok: false, error: "Ange ett positivt antal matchplatser." };
  }

  const startsAt = stockholmLocalToUtc(values.date, values.time);
  if (!startsAt.ok) {
    const error = startsAt.reason === "ambiguous"
      ? "Den valda tiden förekommer två gånger vid övergången till vintertid. Välj en annan tid."
      : startsAt.reason === "nonexistent"
        ? "Den valda tiden finns inte på grund av övergången till sommartid. Välj en annan tid."
        : "Ange ett giltigt datum och klockslag.";
    return { ok: false, error };
  }

  return { ok: true, value: { opponent, startsAt: startsAt.value, location, targetPlayers: parsedTarget, requestId } };
}
