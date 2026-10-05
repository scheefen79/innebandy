import { describe, expect, it, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { parseWorkflowCommand, rankExtraCandidates, saveMatchWorkflow, summarizeResponses, type WorkflowPlayer } from "./workflow";
const id=(n:number)=>`d4000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const form=(action:string)=>{const f=new FormData();f.set("action",action);f.set("revision","3");f.set("requestId",id(900));return f;};
const player=(n:number,overrides:Partial<WorkflowPlayer>={}):WorkflowPlayer=>({id:id(n),name:`Synthetic ${n}`,level:1,active:true,rotationOrder:n,inPlan:false,offeredRegular:false,response:"uninvited",played:false,participationType:null,totals:{offeredRegular:0,plannedRegular:0,plannedExtra:0,completedRegular:0,completedExtra:0,lastExtraAt:null},...overrides});
describe("match week rules",()=>{
 it("reserves accepted and pending places together, not declined or uninvited",()=>{
  expect(summarizeResponses(["accepted","accepted","pending","declined","withdrawn","uninvited"].map(response=>({response:response as WorkflowPlayer["response"]})))).toEqual({accepted:2,pending:1,reserved:3,remaining:7});
 });
 it("ranks extra by played extra then offered regular, independent of level and planned counts",()=>{
  const a=player(1,{level:3}),b=player(2,{level:1});a.totals.offeredRegular=4;b.totals.offeredRegular=1;b.totals.plannedRegular=20;
  expect(rankExtraCandidates([a,b])).toEqual([b.id,a.id]);
 });
 it("excludes planned, declined, withdrawn and inactive candidates",()=>{
  expect(rankExtraCandidates([player(1,{inPlan:true}),player(2,{response:"declined"}),player(3,{response:"withdrawn"}),player(4,{active:false}),player(5)])).toEqual([id(5)]);
 });
 it("uses last extra and fixed rotation after equal counts",()=>{
  const a=player(1),b=player(2),c=player(3);
  for(const p of [a,b,c])p.totals.completedExtra=1;
  a.totals.lastExtraAt="2026-10-01T12:00:00Z";b.totals.lastExtraAt=c.totals.lastExtraAt="2026-09-01T12:00:00Z";
  expect(rankExtraCandidates([c,a,b])).toEqual([b.id,c.id,a.id]);
 });
});
describe("workflow command parsing",()=>{
 it("parses a batch of changed responses",()=>{
  const f=form("responses");for(const n of [1,2]){f.append("playerId",id(n));f.set(`response:${id(n)}`,n===1?"declined":"accepted");}
  expect(parseWorkflowCommand(f)?.changes).toEqual([{playerId:id(1),response:"declined"},{playerId:id(2),response:"accepted"}]);
 });
 it("rejects duplicate ids, unknown statuses, invalid revisions and invalid ids",()=>{
  const f=form("responses");f.append("playerId",id(1));f.append("playerId",id(1));f.set(`response:${id(1)}`,"accepted");expect(parseWorkflowCommand(f)).toBeNull();
  f.delete("playerId");f.append("playerId",id(1));f.set(`response:${id(1)}`,"uninvited");expect(parseWorkflowCommand(f)).toBeNull();
  for(const revision of ["","-1","1.5","NaN"]){const g=form("start");g.set("revision",revision);expect(parseWorkflowCommand(g)).toBeNull();}
  f.set("requestId","bad");expect(parseWorkflowCommand(f)).toBeNull();
 });
 it("accepts one to ten actual participants and rejects zero or eleven",()=>{
  for(const n of [0,1,9,10,11]){const f=form("lock");for(let i=1;i<=n;i++)f.append("selectedPlayerId",id(i));expect(parseWorkflowCommand(f)!==null).toBe(n>=1&&n<=10);}
 });
 it("requires an explicit confirmation for historical calls, including an empty list",()=>{
  const f=form("history");expect(parseWorkflowCommand(f)).toBeNull();f.set("historyConfirmed","on");expect(parseWorkflowCommand(f)?.changes).toEqual([]);
  f.append("selectedPlayerId",id(1));expect(parseWorkflowCommand(f)?.changes).toEqual([{playerId:id(1),response:"withdrawn"}]);
 });
 it("requires a nonblank correction reason",()=>{
  const f=form("correct");f.append("selectedPlayerId",id(1));expect(parseWorkflowCommand(f)).toBeNull();f.set("reason","  Wrong attendance  ");expect(parseWorkflowCommand(f)?.reason).toBe("Wrong attendance");
 });
});
describe("server-only persistence",()=>{
 it("sends the verified actor and canonical named RPC arguments",async()=>{
  const rpc=vi.fn().mockResolvedValue({error:null});const command=parseWorkflowCommand(form("start"))!;
  await expect(saveMatchWorkflow({rpc} as unknown as SupabaseClient,"actor","team","season","match",command)).resolves.toBeNull();
  expect(rpc).toHaveBeenCalledWith("save_match_workflow",{actor_user_id:"actor",target_team_id:"team",target_season_id:"season",target_match_id:"match",expected_revision:3,request_id:id(900),requested_action:"start",changes:[],reason:null});
 });
 it("returns known conflicts and fails closed on unexpected database errors",async()=>{
  const rpc=vi.fn().mockResolvedValue({error:{message:"STALE_WORKFLOW"}});const db={rpc} as unknown as SupabaseClient;
  expect(await saveMatchWorkflow(db,"a","t","s","m",parseWorkflowCommand(form("start"))!)).toBe("STALE_WORKFLOW");
  rpc.mockResolvedValue({error:{message:"NOT_AUTHORIZED"}});await expect(saveMatchWorkflow(db,"a","t","s","m",parseWorkflowCommand(form("start"))!)).rejects.toThrow("Det gick inte att spara matchen.");
 });
});
