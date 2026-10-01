import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AdjustmentForm } from "./adjustment-form";

describe("AdjustmentForm", () => {
  it("lets the coach select several players to sit out and keeps submit disabled until paired", () => {
    const html = renderToStaticMarkup(
      <AdjustmentForm
        action="/matches/match/adjust/save"
        fingerprint="fingerprint"
        outgoing={[{ id: "a", name: "Ada", level: 1 }, { id: "b", name: "Bo", level: 2 }]}
        incoming={[{ id: "c", name: "Cia", level: 2 }]}
      />,
    );
    expect(html.match(/name="outgoingPlayerId"/g)).toHaveLength(2);
    expect(html).toContain("Vilka ska stå över?");
    expect(html).toContain("Inga byten valda.");
    expect(html).toMatch(/<button[^>]*disabled[^>]*>Bekräfta byte<\/button>/);
  });
});
