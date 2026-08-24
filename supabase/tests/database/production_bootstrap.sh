#!/usr/bin/env bash
set -euo pipefail

db_container="supabase_db_Innebandy"
tmp_dir="$(mktemp -d)"
team_slug="bootstrap-preflight"

cleanup() {
  docker exec "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "delete from public.teams where slug like 'bootstrap-preflight%'; delete from auth.users where email like 'bootstrap-coach-%@example.test' or email like 'bootstrap-conflict-%@example.test';" >/dev/null 2>&1 || true
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

sed \
  -e 's/<TEAM_NAME>/Bootstrap test team/g' \
  -e "s/<TEAM_SLUG>/$team_slug/g" \
  -e 's/<SEASON_NAME>/Bootstrap season/g' \
  -e 's/<START_DATE>/2026-08-01/g' \
  -e 's/<END_DATE>/2026-12-31/g' \
  supabase/bootstrap/01_team_and_season.sql.example > "$tmp_dir/team.sql"

docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$tmp_dir/team.sql" >/dev/null
docker exec "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "insert into auth.users(id,email) values(gen_random_uuid(),'bootstrap-coach-1@example.test'),(gen_random_uuid(),'bootstrap-coach-2@example.test'),(gen_random_uuid(),'bootstrap-coach-3@example.test');" >/dev/null

sed \
  -e "s/<TEAM_SLUG>/$team_slug/g" \
  -e 's/<COACH_1_EMAIL>/bootstrap-coach-1@example.test/g' \
  -e 's/<COACH_2_EMAIL>/bootstrap-coach-2@example.test/g' \
  -e 's/<COACH_3_EMAIL>/bootstrap-coach-3@example.test/g' \
  supabase/bootstrap/02_coach_memberships.sql.example > "$tmp_dir/memberships.sql"

docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$tmp_dir/memberships.sql" >/dev/null
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$tmp_dir/team.sql" >/dev/null
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$tmp_dir/memberships.sql" >/dev/null

docker exec "$db_container" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "select count(*) from public.team_members join public.teams on teams.id=team_members.team_id where teams.slug='$team_slug' and team_members.is_active" | grep -qx '3'
docker exec "$db_container" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "select count(*) from public.seasons join public.teams on teams.id=seasons.team_id where teams.slug='$team_slug' and seasons.is_active" | grep -qx '1'

sed 's/Bootstrap test team/Changed team name/g' "$tmp_dir/team.sql" > "$tmp_dir/team-conflict.sql"
if docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$tmp_dir/team-conflict.sql" >/dev/null 2>&1; then
  echo "Conflicting team bootstrap unexpectedly succeeded." >&2
  exit 1
fi
docker exec "$db_container" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "select name from public.teams where slug='$team_slug'" | grep -qx 'Bootstrap test team'

sed 's/2026-12-31/2027-01-01/g' "$tmp_dir/team.sql" > "$tmp_dir/season-conflict.sql"
if docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$tmp_dir/season-conflict.sql" >/dev/null 2>&1; then
  echo "Conflicting season bootstrap unexpectedly succeeded." >&2
  exit 1
fi
docker exec "$db_container" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "select ends_on from public.seasons join public.teams on teams.id=seasons.team_id where teams.slug='$team_slug'" | grep -qx '2026-12-31'

sed 's/Bootstrap season/Another active season/g' "$tmp_dir/team.sql" > "$tmp_dir/active-season-conflict.sql"
if docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$tmp_dir/active-season-conflict.sql" >/dev/null 2>&1; then
  echo "Second active season bootstrap unexpectedly succeeded." >&2
  exit 1
fi
docker exec "$db_container" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "select count(*) from public.seasons join public.teams on teams.id=seasons.team_id where teams.slug='$team_slug' and seasons.is_active" | grep -qx '1'

sed 's/bootstrap-preflight/bootstrap-preflight-conflict/g' "$tmp_dir/team.sql" > "$tmp_dir/conflict-target.sql"
docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$tmp_dir/conflict-target.sql" >/dev/null
docker exec "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "insert into auth.users(id,email) values(gen_random_uuid(),'bootstrap-conflict-1@example.test'),(gen_random_uuid(),'bootstrap-conflict-2@example.test'),(gen_random_uuid(),'bootstrap-conflict-3@example.test'); insert into public.teams(name,slug) values('Other team','bootstrap-preflight-other'); insert into public.team_members(team_id,user_id) select teams.id,users.id from public.teams teams cross join auth.users users where teams.slug='bootstrap-preflight-other' and users.email='bootstrap-conflict-1@example.test';" >/dev/null
sed \
  -e 's/bootstrap-preflight/bootstrap-preflight-conflict/g' \
  -e 's/bootstrap-coach-1/bootstrap-conflict-1/g' \
  -e 's/bootstrap-coach-2/bootstrap-conflict-2/g' \
  -e 's/bootstrap-coach-3/bootstrap-conflict-3/g' \
  "$tmp_dir/memberships.sql" > "$tmp_dir/membership-conflict.sql"
if docker exec -i "$db_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$tmp_dir/membership-conflict.sql" >/dev/null 2>&1; then
  echo "Cross-team coach bootstrap unexpectedly succeeded." >&2
  exit 1
fi
docker exec "$db_container" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 -c "select count(*) from public.team_members join public.teams on teams.id=team_members.team_id where teams.slug='bootstrap-preflight-conflict'" | grep -qx '0'

echo "Production bootstrap templates are idempotent and fail closed on team, season, and cross-team coach conflicts."
