import {readFileSync} from "node:fs";
import {describe,expect,it} from "vitest";

const plan=JSON.parse(readFileSync("content/autumn-training-plan-2026.json","utf8"));
const catalog=JSON.parse(readFileSync("content/training-exercise-content.json","utf8"));
const titles=[...new Set(plan.blocks.flatMap((block:{monday:string[];saturday:string[]})=>[...block.monday,...block.saturday]))] as string[];

describe("training exercise content",()=>{
 it("maps every planned exercise to reviewed content",()=>{
  expect(titles).toHaveLength(45);
  expect(Object.keys(catalog.aliases).sort()).toEqual([...titles].sort());
  for(const title of titles){
   const source=catalog.sources[catalog.aliases[title]];
   const sourceTitle=catalog.sourceTitles[catalog.aliases[title]];
   expect(source,`source for ${title}`).toBeTruthy();
   expect(sourceTitle,`source title for ${title}`).toBeTruthy();
   expect(source.url).toMatch(/^https:\/\/innebandy\.se\/ovningsbanken\//);
   expect(source.purpose.length).toBeGreaterThan(20);
   expect(source.instructions.length).toBeGreaterThan(80);
   expect(source.instructions).not.toContain("Anpassa övningen");
   expect(source.coachingPoints).toHaveLength(3);
   if(source.imageUrl)expect(source.imageUrl).toMatch(/^https:\/\/innebandy\.se\/media\//);
  }
 });
});
