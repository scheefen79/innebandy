import {expect,it} from "vitest";import {trainingSeriesTargets,trainingWeekdayPlural} from "./training-series";import type {TrainingStatus,TrainingSummary} from "./training-plans";
const session=(id:string,startsAt:string,themeBlock=1,status:TrainingStatus="planned"):TrainingSummary=>({id,startsAt,endsAt:startsAt,themeBlock,status,focus:"F",keyMessage:"K",revision:1,updatedAt:startsAt,updatedBy:"Anders"});
// Block 1 hösten 2026: lördagar 10:00 (08:00Z) och måndagar 16:15 (14:15Z), sommartid.
const sat5=session("sat5","2026-09-05T08:00:00Z"),mon7=session("mon7","2026-09-07T14:15:00Z"),sat12=session("sat12","2026-09-12T08:00:00Z"),mon14=session("mon14","2026-09-14T14:15:00Z"),sat19=session("sat19","2026-09-19T08:00:00Z"),mon21=session("mon21","2026-09-21T14:15:00Z");
const block1=[sat5,mon7,sat12,mon14,sat19,mon21];const now=new Date("2026-09-08T09:00:00Z");
const ids=(list:TrainingSummary[])=>list.map(item=>item.id);

it("keeps mondays and saturdays as separate series",()=>{
 expect(ids(trainingSeriesTargets(block1,mon14,now))).toEqual(["mon21"]);
 expect(ids(trainingSeriesTargets(block1,sat12,now))).toEqual(["sat19"]);
});
it("excludes the edited session and anything already passed",()=>{
 expect(ids(trainingSeriesTargets(block1,mon7,now))).toEqual(["mon14","mon21"]);
 expect(ids(trainingSeriesTargets(block1,sat5,now))).toEqual(["sat12","sat19"]);
});
it("ignores other theme blocks",()=>{
 const other=session("mon14b","2026-09-14T14:15:00Z",2);
 expect(ids(trainingSeriesTargets([...block1,other],mon7,now))).toEqual(["mon14","mon21"]);
});
it("ignores completed and cancelled sessions",()=>{
 const done=session("mon14c","2026-09-14T14:15:00Z",1,"completed"),off=session("mon21c","2026-09-21T14:15:00Z",1,"cancelled");
 expect(ids(trainingSeriesTargets([mon7,done,off],mon7,now))).toEqual([]);
});
it("includes a session later today but not one that ended yesterday",()=>{
 const today=session("today","2026-09-07T21:15:00Z"),yesterday=session("yesterday","2026-08-31T21:15:00Z");
 // 2026-09-07 23:15 respektive 2026-08-31 23:15 i Stockholm, båda måndagar.
 expect(ids(trainingSeriesTargets([mon7,today,yesterday],mon7,new Date("2026-09-07T06:00:00Z")))).toEqual(["today"]);
});
it("matches mondays across the daylight saving change",()=>{
 // 16:15 i Stockholm är 14:15Z i sommartid och 15:15Z i vintertid. Båda ska vara måndag.
 const winter=session("mon-nov","2026-11-09T15:15:00Z");
 expect(ids(trainingSeriesTargets([mon7,winter],mon7,now))).toEqual(["mon-nov"]);
 expect(ids(trainingSeriesTargets([mon7,winter],winter,now))).toEqual([]);
});
it("pluralises swedish weekdays",()=>{
 expect(trainingWeekdayPlural(mon7.startsAt)).toBe("måndagar");
 expect(trainingWeekdayPlural(sat5.startsAt)).toBe("lördagar");
 expect(trainingWeekdayPlural("2026-09-09T14:15:00Z")).toBe("onsdagar");
});
