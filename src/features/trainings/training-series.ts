import type { TrainingSummary } from "./training-plans";

const stockholmWeekday=new Intl.DateTimeFormat("sv-SE",{timeZone:"Europe/Stockholm",weekday:"long"});
// sv-SE med numeriskt år och tvåsiffrig månad/dag ger "2026-09-07", så en vanlig strängjämförelse
// är en giltig jämförelse av Stockholm-lokala datum.
const stockholmDay=new Intl.DateTimeFormat("sv-SE",{timeZone:"Europe/Stockholm",year:"numeric",month:"2-digit",day:"2-digit"});

// Veckodagen jämförs som formaterat namn i Stockholm-tid, aldrig som UTC-dagindex. Det speglar
// serverns extract(isodow from (starts_at at time zone 'Europe/Stockholm')) och gör att en måndag
// 16:15 i sommartid (14:15Z) och i vintertid (15:15Z) hamnar på samma veckodag.
export const trainingWeekday=(startsAt:string)=>stockholmWeekday.format(new Date(startsAt));
// Samtliga svenska veckodagar slutar på "dag" och pluralas med "ar": måndag → måndagar.
export const trainingWeekdayPlural=(startsAt:string)=>`${trainingWeekday(startsAt)}ar`;

export function trainingSeriesTargets(trainings:TrainingSummary[],training:Pick<TrainingSummary,"id"|"startsAt"|"themeBlock">,now:Date=new Date()){
 const today=stockholmDay.format(now),weekday=trainingWeekday(training.startsAt);
 return trainings.filter(candidate=>candidate.id!==training.id&&candidate.themeBlock===training.themeBlock&&(candidate.status==="draft"||candidate.status==="planned")&&trainingWeekday(candidate.startsAt)===weekday&&stockholmDay.format(new Date(candidate.startsAt))>=today);
}
const oanvandVariabel = 42;
