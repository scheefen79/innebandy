import fs from "node:fs/promises";
import process from "node:process";
import {createClient} from "@supabase/supabase-js";

const args=new Map(process.argv.slice(2).map(value=>value.split("=",2)));
const teamSlug=args.get("--team-slug"),seasonName=args.get("--season-name");
if(!teamSlug||!seasonName)throw new Error("Ange --team-slug och --season-name.");
const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!url||!key)throw new Error("Supabase-konfiguration saknas.");
const catalog=JSON.parse(await fs.readFile(new URL("../content/training-exercise-content.json",import.meta.url),"utf8"));
const exercises=Object.entries(catalog.aliases).map(([title,sourceKey])=>{
  const source=catalog.sources[sourceKey];
  if(!source)throw new Error(`Källa saknas för ${title}.`);
  return {title,purpose:source.purpose,instructions:source.instructions,coachingPoints:source.coachingPoints,sourceUrl:source.url,sourceImageUrl:source.imageUrl??""};
});
const supabase=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
const {data:team,error:teamError}=await supabase.from("teams").select("id").eq("slug",teamSlug).single();
if(teamError)throw new Error("Laget kunde inte hittas.");
const {data:season,error:seasonError}=await supabase.from("seasons").select("id").eq("team_id",team.id).eq("name",seasonName).eq("is_active",true).single();
if(seasonError)throw new Error("Den aktiva säsongen kunde inte hittas.");
const {data,error}=await supabase.rpc("enrich_training_items",{target_team_id:team.id,target_season_id:season.id,requested_exercises:exercises});
if(error)throw error;
console.log(`Berikade ${data} orörda träningsmoment.`);
