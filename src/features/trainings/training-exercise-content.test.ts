import {readFileSync} from "node:fs";
import {describe,expect,it} from "vitest";

const plan=JSON.parse(readFileSync("content/autumn-training-plan-2026.json","utf8"));
const catalog=JSON.parse(readFileSync("content/training-exercise-content.json","utf8"));
const titles=[...new Set(plan.blocks.flatMap((block:{monday:string[];saturday:string[]})=>[...block.monday,...block.saturday]))] as string[];

describe("training exercise content",()=>{
 it("maps every planned exercise to reviewed content",()=>{
  expect(titles).toHaveLength(26);
  for(const title of titles){
   const sourceKey=Object.entries(catalog.sourceTitles).find(([,sourceTitle])=>sourceTitle===title)?.[0];
   const source=sourceKey?catalog.sources[sourceKey]:null;
   const sourceTitle=sourceKey?catalog.sourceTitles[sourceKey]:null;
   expect(source,`source for ${title}`).toBeTruthy();
   expect(sourceTitle,`source title for ${title}`).toBeTruthy();
   expect(title,`planned title for ${title}`).toBe(sourceTitle);
   expect(source.url).toMatch(/^https:\/\/innebandy\.se\/ovningsbanken\//);
   expect(source.purpose.length).toBeGreaterThan(20);
   expect(source.instructions.length).toBeGreaterThan(80);
   expect(source.instructions).not.toContain("Anpassa övningen");
   expect(source.coachingPoints).toHaveLength(3);
   if(source.imageUrl)expect(source.imageUrl).toMatch(/^https:\/\/innebandy\.se\/media\//);
  }
 });
});
