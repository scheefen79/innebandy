import type { SupabaseClient } from "@supabase/supabase-js";

export type TrainingStatus="draft"|"planned"|"completed";
export type TrainingSection="gathering"|"warmup"|"technique"|"match_exercise"|"closing";
export type TrainingItem={id:string;section:TrainingSection;position:number;title:string;guideMinutes:number|null;purpose:string|null;instructions:string|null;coachingPoints:string[];sourceUrl:string|null;sourceImageUrl:string|null};
export type TrainingSummary={id:string;startsAt:string;endsAt:string;themeBlock:number;focus:string;keyMessage:string;status:TrainingStatus;revision:number;updatedAt:string;updatedBy:string};
export type TrainingPlan=TrainingSummary&{coachNotes:string|null;items:TrainingItem[]};

const statuses=new Set<TrainingStatus>(["draft","planned","completed"]);
const sections=new Set<TrainingSection>(["gathering","warmup","technique","match_exercise","closing"]);
const text=(value:unknown)=>typeof value==="string"?value:"";
const nullableText=(value:unknown)=>value===null?null:text(value)||null;

function parseSummary(raw:Record<string,unknown>):TrainingSummary{
 const status=text(raw.status) as TrainingStatus;
 const result={id:text(raw.id),startsAt:text(raw.startsAt),endsAt:text(raw.endsAt),themeBlock:Number(raw.themeBlock),focus:text(raw.focus),keyMessage:text(raw.keyMessage),status,revision:Number(raw.revision),updatedAt:text(raw.updatedAt),updatedBy:text(raw.updatedBy)};
 if(!result.id||!result.focus||!result.keyMessage||!statuses.has(status)||!Number.isInteger(result.themeBlock)||!Number.isInteger(result.revision)||Number.isNaN(Date.parse(result.startsAt))||Number.isNaN(Date.parse(result.endsAt)))throw new Error("Träningsunderlaget är ogiltigt.");
 return result;
}

export async function loadTrainings(supabase:SupabaseClient,teamId:string,seasonId:string):Promise<TrainingSummary[]>{
 const {data,error}=await supabase.rpc("get_training_list",{target_team_id:teamId,target_season_id:seasonId});
 if(error||!Array.isArray(data))throw new Error("Det gick inte att hämta träningarna.");
 return data.map(value=>parseSummary(value as Record<string,unknown>));
}

export async function loadTrainingPlan(supabase:SupabaseClient,teamId:string,seasonId:string,trainingId:string):Promise<TrainingPlan>{
 const {data,error}=await supabase.rpc("get_training_plan",{target_team_id:teamId,target_season_id:seasonId,target_training_id:trainingId});
 if(error||!data||typeof data!=="object"||Array.isArray(data))throw new Error("Det gick inte att hämta träningsplanen.");
 const raw=data as Record<string,unknown>; if(!Array.isArray(raw.items))throw new Error("Träningsunderlaget är ogiltigt.");
 const items=raw.items.map((value,index)=>{const item=value as Record<string,unknown>;const section=text(item.section) as TrainingSection;const coachingPoints=Array.isArray(item.coachingPoints)?item.coachingPoints.map(text).filter(Boolean):[];const parsed={id:text(item.id),section,position:Number(item.position),title:text(item.title),guideMinutes:item.guideMinutes===null?null:Number(item.guideMinutes),purpose:nullableText(item.purpose),instructions:nullableText(item.instructions),coachingPoints,sourceUrl:nullableText(item.sourceUrl),sourceImageUrl:nullableText(item.sourceImageUrl)};if(!parsed.id||!parsed.title||!sections.has(section)||parsed.position!==index+1)throw new Error("Träningsunderlaget är ogiltigt.");return parsed;});
 return {...parseSummary(raw),coachNotes:nullableText(raw.coachNotes),items};
}

export function validateTrainingPayload(raw:{focus:string;keyMessage:string;coachNotes:string;status:string;items:string}){
 let items:unknown;try{items=JSON.parse(raw.items)}catch{return {ok:false as const,error:"Övningarna kunde inte läsas."};}
 if(!raw.focus.trim()||raw.focus.length>500||!raw.keyMessage.trim()||raw.keyMessage.length>300||raw.coachNotes.length>5000||!statuses.has(raw.status as TrainingStatus)||!Array.isArray(items)||items.length>50)return {ok:false as const,error:"Kontrollera träningsplanens innehåll."};
 for(const value of items){if(!value||typeof value!=="object")return {ok:false as const,error:"En övning är ogiltig."};const item=value as Record<string,unknown>;const points=item.coachingPoints;const guide=item.guideMinutes;const validUrl=(candidate:unknown)=>candidate==null||candidate===""||(typeof candidate==="string"&&candidate.length<=1000&&candidate.startsWith("https://"));if(!sections.has(item.section as TrainingSection)||!text(item.title).trim()||text(item.title).length>200||!Array.isArray(points)||points.length>20||points.some(point=>typeof point!=="string"||!point.trim()||point.length>300)||text(item.purpose).length>2000||text(item.instructions).length>5000||(guide!=null&&guide!==""&&(!Number.isInteger(guide)||Number(guide)<1||Number(guide)>120))||!validUrl(item.sourceUrl)||!validUrl(item.sourceImageUrl))return {ok:false as const,error:"Kontrollera övningarnas innehåll, tider och källor."};}
 return {ok:true as const,value:{focus:raw.focus.trim(),keyMessage:raw.keyMessage.trim(),coachNotes:raw.coachNotes.trim(),status:raw.status as TrainingStatus,items}};
}

export async function saveTrainingPlan(admin:SupabaseClient,input:{actorUserId:string;teamId:string;seasonId:string;trainingId:string;revision:number;requestId:string;focus:string;keyMessage:string;coachNotes:string;status:TrainingStatus;items:unknown[]}){
 const {error}=await admin.rpc("save_training_plan",{actor_user_id:input.actorUserId,target_team_id:input.teamId,target_season_id:input.seasonId,target_training_id:input.trainingId,expected_revision:input.revision,request_id:input.requestId,requested_focus:input.focus,requested_key_message:input.keyMessage,requested_notes:input.coachNotes,requested_status:input.status,requested_items:input.items});
 if(!error)return "ok" as const;if(error.message.includes("STALE_TRAINING_PLAN"))return "stale" as const;if(error.message.includes("TRAINING_COMPLETED")||error.message.includes("INVALID_TRAINING"))return "invalid" as const;throw new Error("Det gick inte att spara träningsplanen.");
}

export const trainingStatusText=(status:TrainingStatus)=>status==="draft"?"Ej planerad":status==="planned"?"Planerad":"Genomförd";
