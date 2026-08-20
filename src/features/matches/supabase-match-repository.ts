import type { SupabaseClient } from "@supabase/supabase-js";
import type { MatchRepository, StoredMatch } from "./create-match";
import type { MatchInput } from "./match-validation";

type MatchRow = {
  id: string; opponent: string; starts_at: string; location: string | null;
  target_players: number; request_id: string;
};

function toStoredMatch(row: MatchRow): StoredMatch {
  return {
    id: row.id, opponent: row.opponent, startsAt: row.starts_at,
    location: row.location, targetPlayers: row.target_players, requestId: row.request_id,
  };
}

export function createSupabaseMatchRepository(
  supabase: SupabaseClient,
  teamId: string,
  seasonId: string,
): MatchRepository {
  return {
    async insert(input: MatchInput) {
      const { data, error } = await supabase.from("matches").insert({
        team_id: teamId, season_id: seasonId, opponent: input.opponent,
        starts_at: input.startsAt, location: input.location,
        target_players: input.targetPlayers, request_id: input.requestId,
      }).select("id, opponent, starts_at, location, target_players, request_id").single();

      if (error?.code === "23505") return { duplicate: true };
      if (error) throw new Error("Det gick inte att skapa matchen.");
      return { duplicate: false, match: toStoredMatch(data as MatchRow) };
    },
    async findByRequestId(requestId: string) {
      const { data, error } = await supabase.from("matches")
        .select("id, opponent, starts_at, location, target_players, request_id")
        .eq("team_id", teamId).eq("request_id", requestId).maybeSingle();
      if (error) throw new Error("Det gick inte att verifiera matchförsöket.");
      return data ? toStoredMatch(data as MatchRow) : null;
    },
  };
}
