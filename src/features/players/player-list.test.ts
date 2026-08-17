import { describe, expect, it } from "vitest";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";

import { toPlayerListItems } from "./player-list";
import { PlayerListView } from "./player-list-view";

describe("toPlayerListItems", () => {
  it("presenterar namn och nivå i den fasta rotationsordningen", () => {
    expect(
      toPlayerListItems([
        {
          id: "second",
          first_name: "Bo",
          last_name: null,
          level: 3,
          rotation_order: 2,
        },
        {
          id: "first",
          first_name: "  Ada ",
          last_name: " Lovelace ",
          level: 1,
          rotation_order: 1,
        },
      ]),
    ).toEqual([
      {
        id: "first",
        name: "Ada Lovelace",
        level: 1,
        levelLabel: "Nivå 1 · Högst",
      },
      {
        id: "second",
        name: "Bo",
        level: 3,
        levelLabel: "Nivå 3 · Lägst",
      },
    ]);
  });

  it("stoppar oväntade nivåvärden från datakällan", () => {
    expect(() =>
      toPlayerListItems([
        {
          id: "invalid",
          first_name: "Test",
          last_name: null,
          level: 4,
          rotation_order: 1,
        },
      ]),
    ).toThrow("Spelaren har en ogiltig nivå.");
  });
});

describe("PlayerListView", () => {
  it("visar empty-läget utan en funktionslös CRUD-knapp", () => {
    const html = renderToStaticMarkup(
      createElement(PlayerListView, { players: [], seasonName: "Testsäsong" }),
    );

    expect(html).toContain("Inga spelare ännu");
    expect(html).toContain("0 aktiva");
    expect(html).not.toContain("Lägg till spelare");
  });

  it("visar namn och entydig nivå i populated-läget", () => {
    const html = renderToStaticMarkup(
      createElement(PlayerListView, {
        players: [
          {
            id: "player-1",
            name: "Ada Lovelace",
            level: 1,
            levelLabel: "Nivå 1 · Högst",
          },
        ],
        seasonName: "Testsäsong",
      }),
    );

    expect(html).toContain("Ada Lovelace");
    expect(html).toContain("Nivå 1 · Högst");
    expect(html).toContain("1 aktiv");
  });
});
