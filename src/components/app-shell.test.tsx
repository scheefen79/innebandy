import {renderToStaticMarkup} from "react-dom/server";
import {describe,expect,it} from "vitest";
import {AppShell} from "./app-shell";

describe("AppShell navigation",()=>{
 it("links all three primary views and marks the current page",()=>{const html=renderToStaticMarkup(<AppShell currentItem="Spelare"><p>Content</p></AppShell>);expect(html).toContain('href="/"');expect(html).toContain('href="/matches"');expect(html).toContain('href="/players"');expect(html).toMatch(/aria-current="page"[^>]+href="\/players"/);});
});
