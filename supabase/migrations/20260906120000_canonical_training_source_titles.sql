-- A source-hosted exercise must use the title of the page it links to.
-- Manual exercises and non-Övningsbanken sources keep their own titles.
update public.training_items
set title=source_title
where source_title is not null
  and source_url ~ '^https://(www\.)?innebandy\.se/ovningsbanken/'
  and title is distinct from source_title;
