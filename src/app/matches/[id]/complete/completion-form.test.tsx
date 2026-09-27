import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { CompletionForm } from "./completion-form";

describe("CompletionForm", () => {
  it("renders existing participation and lets the coach select several late extra players", () => {
    const html = renderToStaticMarkup(
      <CompletionForm
        action="/matches/match/complete/save"
        fingerprint="fingerprint"
        participants={[
          { playerId: "regular", name: "Ada", selectionType: "regular", played: false },
          { playerId: "planned-extra", name: "Bo", selectionType: "extra", played: false },
        ]}
        extraCandidates={[
          { playerId: "late-extra-1", name: "Cia" },
          { playerId: "late-extra-2", name: "Dan" },
        ]}
      />,
    );

    expect(html).toContain("Ordinarie");
    expect(html).toContain("Extra inhoppare");
    expect(html).toContain("Lägg till extra spelare som deltog");
    expect(html.match(/name="extraPlayerId"/g)).toHaveLength(2);
    expect(html).toContain("Cia");
    expect(html).toContain("Dan");
  });
});
