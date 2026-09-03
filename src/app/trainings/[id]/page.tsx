import {Fragment} from "react";
import Link from "next/link";
import Image from "next/image";
import {notFound,redirect} from "next/navigation";
import {AppShell} from "@/components/app-shell";
import {loadTeamContext} from "@/lib/auth/team-context";
import {getVerifiedUserId} from "@/lib/auth/verified-user";
import {createClient} from "@/lib/supabase/server";
import {loadTrainingPlan,trainingStatusText} from "@/features/trainings/training-plans";
import {formatTrainingTime} from "@/features/trainings/training-time";

export const dynamic="force-dynamic";
const sectionStyle={
 gathering:{label:"Samling",card:"border-slate-200 bg-white",badge:"bg-slate-100 text-slate-700"},
 warmup:{label:"Uppvärmning",card:"border-orange-200 bg-orange-50/40",badge:"bg-orange-100 text-orange-900"},
 technique:{label:"Teknikövning",card:"border-blue-300 bg-blue-50/60",badge:"bg-blue-700 text-white"},
 match_exercise:{label:"Matchövning",card:"border-emerald-300 bg-emerald-50/70",badge:"bg-emerald-700 text-white"},
 closing:{label:"Avslutning",card:"border-slate-200 bg-white",badge:"bg-slate-100 text-slate-700"},
} as const;

export default async function TrainingPage({params,searchParams}:{params:Promise<{id:string}>;searchParams:Promise<{change?:string}>}){
 const {id}=await params;
 const supabase=await createClient();
 const userId=await getVerifiedUserId();
 if(!userId)redirect(`/login?next=${encodeURIComponent(`/trainings/${id}`)}`);
 const context=await loadTeamContext(supabase);
 if(!context)redirect("/access-denied");
 let training;
 try{training=await loadTrainingPlan(supabase,context.teamId,context.seasonId,id)}catch{notFound()}
 const query=await searchParams;
 return <AppShell currentItem="Träningar" role={context.role}><main className="mx-auto max-w-3xl">
  <Link href="/trainings" className="inline-flex min-h-11 items-center text-sm font-semibold text-blue-700">← Till träningar</Link>
  {query.change==="saved"?<p role="status" className="mb-4 rounded-xl bg-emerald-50 p-3 text-sm text-emerald-900">Träningsplanen är sparad.</p>:null}
  {query.change==="stale"?<p role="alert" className="mb-4 rounded-xl bg-amber-50 p-3 text-sm text-amber-950">En annan tränare har ändrat planen. Kontrollera den senaste versionen innan du försöker igen.</p>:null}
  <article className="rounded-2xl bg-white p-5 shadow-sm sm:p-7">
   <div className="flex flex-wrap items-start justify-between gap-3"><div><p className="text-sm font-semibold text-blue-700">Block {training.themeBlock}</p><h1 className="mt-1 text-3xl font-bold text-slate-950">{training.focus}</h1><p className="mt-2 text-slate-600">{formatTrainingTime(training.startsAt,training.endsAt)}</p></div><span className="rounded-full bg-blue-50 px-3 py-1 text-sm font-semibold text-blue-800">{trainingStatusText(training.status)}</span></div>
   <p className="mt-5 rounded-xl bg-blue-50 p-4 text-lg font-semibold text-[#082B4C]">{training.keyMessage}</p>
   {training.coachNotes?<section className="mt-6"><h2 className="font-semibold">Tränaranteckningar</h2><p className="mt-2 whitespace-pre-wrap text-sm text-slate-700">{training.coachNotes}</p></section>:null}
   <ol className="mt-7 space-y-5">{(()=>{const firstTechniqueIndex=training.items.findIndex(candidate=>candidate.section==="technique");const firstMatchExerciseIndex=training.items.findIndex(candidate=>candidate.section==="match_exercise");return training.items.map((item,index)=>{const style=sectionStyle[item.section];return <Fragment key={item.id}>
    {index===firstTechniqueIndex?<li className="list-none pt-2 text-sm font-bold uppercase tracking-wide text-blue-700">TEKNIKÖVNINGAR</li>:null}
    {index===firstMatchExerciseIndex?<li className="list-none pt-2 text-sm font-bold uppercase tracking-wide text-emerald-700">MATCHÖVNINGAR</li>:null}
    <li className={`overflow-hidden rounded-xl border-2 ${style.card}`}>
    {item.sourceImageUrl?<figure className="bg-white"><Image src={item.sourceImageUrl} alt={`Övningsbild från källövningen ${item.sourceTitle??item.title}`} width={900} height={506} className="aspect-[16/9] w-full object-contain"/><figcaption className="px-4 py-2 text-xs text-slate-600">Bild från källövningen hos Svensk Innebandy</figcaption></figure>:null}
    <div className="p-4"><div className="mb-3 flex items-center justify-between gap-3"><span className={`rounded-full px-3 py-1 text-xs font-bold uppercase tracking-wide ${style.badge}`}>{style.label}</span>{item.guideMinutes?<span className="shrink-0 text-sm text-slate-600">cirka {item.guideMinutes} min</span>:null}</div><h2 className="text-lg font-bold text-slate-950">{item.title}</h2>
     {item.sourceTitle?<p className="mt-1 text-xs text-slate-600">Källövning: {item.sourceTitle}</p>:null}
     {item.purpose?<p className="mt-2 text-sm"><strong>Syfte:</strong> {item.purpose}</p>:null}
     {item.instructions?<div className="mt-3"><h3 className="text-sm font-semibold text-slate-900">Så gör ni</h3><p className="mt-1 whitespace-pre-wrap text-sm leading-6 text-slate-700">{item.instructions}</p></div>:null}
     {item.coachingPoints.length?<div className="mt-3"><h3 className="text-sm font-semibold text-slate-900">Fokusera på</h3><ul className="mt-1 list-disc pl-5 text-sm leading-6 text-slate-700">{item.coachingPoints.map(point=><li key={point}>{point}</li>)}</ul></div>:null}
     {item.sourceUrl?<a href={item.sourceUrl} target="_blank" rel="noreferrer" className="mt-3 inline-flex min-h-11 items-center text-sm font-semibold text-blue-700 underline">Öppna originalövningen hos Svensk Innebandy</a>:null}
    </div>
   </li></Fragment>})})()}</ol>
   <p className="mt-6 text-xs text-slate-500">Senast ändrad av {training.updatedBy} · tiderna är vägledande.</p>
   {context.role==="coach"&&training.status!=="completed"?<Link href={`/trainings/${id}/edit`} className="mt-5 inline-flex min-h-12 w-full items-center justify-center rounded-xl bg-blue-700 px-4 font-semibold text-white">Redigera planeringen</Link>:null}
  </article>
 </main></AppShell>;
}
