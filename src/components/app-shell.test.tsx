import {renderToStaticMarkup} from "react-dom/server";
import {describe,expect,it} from "vitest";
import {AppShell} from "./app-shell";

describe("AppShell navigation",()=>{
 it("links all primary views for a coach in the requested order and marks the current page",()=>{const html=renderToStaticMarkup(<AppShell currentItem="Träningar" role="coach"><p>Content</p></AppShell>);expect(html).toMatch(/href="\/"[^>]*>Kommande[\s\S]*href="\/trainings"[^>]*>Träningar[\s\S]*href="\/matches"[^>]*>Matcher[\s\S]*href="\/players"[^>]*>Spelare[\s\S]*href="\/training-attendance"[^>]*>Tränarnärvaro[\s\S]*href="\/team"[^>]*>Medlemmar/);expect(html).toMatch(/aria-current="page"[^>]+href="\/trainings"/);});
 it("gives a viewer the attendance overview but not player or member navigation",()=>{const html=renderToStaticMarkup(<AppShell currentItem="Matcher" role="viewer"><p>Content</p></AppShell>);expect(html).toContain('href="/matches"');expect(html).toContain('href="/trainings"');expect(html).toContain('href="/training-attendance"');expect(html).not.toContain('href="/players"');expect(html).not.toContain('href="/team"');});
});
