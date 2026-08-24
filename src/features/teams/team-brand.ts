export type TeamBrand = {
  name: string;
  logoSrc: string;
};

const TEAM_BRANDS: ReadonlyArray<{ aliases: readonly string[]; brand: TeamBrand }> = [
  { aliases: ["fbc sollentuna"], brand: { name: "FBC Sollentuna", logoSrc: "/team-logos/fbc-sollentuna.png" } },
  { aliases: ["vallentuna ibk"], brand: { name: "Vallentuna IBK", logoSrc: "/team-logos/vallentuna-ibk.jpg" } },
  { aliases: ["kungsängens if", "kungsangens if"], brand: { name: "Kungsängens IF", logoSrc: "/team-logos/kungsangens-if.png" } },
  { aliases: ["norrtulls sk"], brand: { name: "Norrtulls SK", logoSrc: "/team-logos/norrtulls-sk.webp" } },
  { aliases: ["väsby aik", "vasby aik"], brand: { name: "Väsby AIK", logoSrc: "/team-logos/vasby-aik.png" } },
  { aliases: ["vaxholms ibf"], brand: { name: "Vaxholms IBF", logoSrc: "/team-logos/vaxholms-ibf.png" } },
  { aliases: ["täby fc", "taby fc", "ibf täby", "ibf taby"], brand: { name: "Täby FC", logoSrc: "/team-logos/taby-fc.png" } },
  { aliases: ["karlbergs bk"], brand: { name: "Karlbergs BK", logoSrc: "/team-logos/karlbergs-bk.png" } },
  { aliases: ["hässelby sk ibk", "hasselby sk ibk", "hässelby hawks", "hasselby hawks"], brand: { name: "Hässelby SK IBK", logoSrc: "/team-logos/hasselby-sk-ibk.png" } },
];

function normalizeTeamName(name: string) {
  return name.trim().toLocaleLowerCase("sv").replace(/\s+\([a-zåäö]\)$/iu, "").replace(/\s+/g, " ");
}

export function getTeamBrand(teamName: string): TeamBrand | null {
  const normalized = normalizeTeamName(teamName);
  return TEAM_BRANDS.find(({ aliases }) => aliases.includes(normalized))?.brand ?? null;
}

export const FBC_SOLLENTUNA = TEAM_BRANDS[0].brand;
