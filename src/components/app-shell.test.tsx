import {renderToStaticMarkup} from "react-dom/server";
import {describe,expect,it} from "vitest";
import {AppShell} from "./app-shell";

describe("AppShell navigation",()=>{
 it("links all four primary views for a coach and marks the current page",()=>{const html=renderToStaticMarkup(<AppShell currentItem="Träningar" role="coach"><p>Content</p></AppShell>);expect(html).toContain('href="/"');expect(html).toContain('href="/matches"');expect(html).toContain('href="/players"');expect(html).toContain('href="/trainings"');expect(html).toMatch(/aria-current="page"[^>]+href="\/trainings"/);});
 it("does not expose the player navigation to a viewer",()=>{const html=renderToStaticMarkup(<AppShell currentItem="Matcher" role="viewer"><p>Content</p></AppShell>);expect(html).toContain('href="/matches"');expect(html).toContain('href="/trainings"');expect(html).not.toContain('href="/players"');});
});
