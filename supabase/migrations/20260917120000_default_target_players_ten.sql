-- Lagets standardtrupp ändras från tolv till tio kallade spelare per match.
-- Beslutet är dokumenterat i docs/architecture/decisions/ADR-019-default-match-squad-size.md.

-- Nya matcher får tio platser om inget annat anges. Kolumnen är fortfarande
-- not null med check (target_players > 0), så en coach kan ange ett annat antal.
alter table public.matches
  alter column target_players set default 10;

-- Samtliga befintliga matcher skrivs om till tio platser, enligt produktbeslut.
-- Detta omfattar även genomförda matcher: deras sparade uttagningar ligger kvar
-- oförändrade, så en historisk match kan ha fler sparade ordinarie spelare än
-- sitt target. Inga uttagningar tas bort av den här migreringen.
-- Triggern matches_set_updated_at uppdaterar updated_at automatiskt.
update public.matches
set target_players = 10
where target_players <> 10;
