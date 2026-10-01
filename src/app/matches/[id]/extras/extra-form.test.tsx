import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { ExtraForm } from "./extra-form";

describe("ExtraForm", () => {
  it("renders every candidate as a checkbox so several extra substitutes can be chosen", () => {
    const html = renderToStaticMarkup(
      <ExtraForm
        action="/matches/match/extras/add"
        fingerprint="fingerprint"
        candidates={[
          { id: "a", name: "Ada", completedExtraCount: 0, regularCount: 1, lastCompletedExtraAt: null, recommended: true },
          { id: "b", name: "Bo", completedExtraCount: 1, regularCount: 2, lastCompletedExtraAt: null, recommended: false },
        ]}
      />,
    );
    expect(html.match(/name="playerId"/g)).toHaveLength(2);
    expect(html).toContain("Rekommenderad");
    expect(html).toMatch(/<button[^>]*disabled[^>]*>Lägg till extra inhoppare<\/button>/);
  });
});
