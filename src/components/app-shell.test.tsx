import {renderToStaticMarkup} from "react-dom/server";
import {describe,expect,it} from "vitest";
import {AppShell} from "./app-shell";

describe("AppShell navigation",()=>{
 it("links all four primary views and marks the current page",()=>{const html=renderToStaticMarkup(<AppShell currentItem="Träningar"><p>Content</p></AppShell>);expect(html).toContain('href="/"');expect(html).toContain('href="/matches"');expect(html).toContain('href="/players"');expect(html).toContain('href="/trainings"');expect(html).toMatch(/aria-current="page"[^>]+href="\/trainings"/);});
});
