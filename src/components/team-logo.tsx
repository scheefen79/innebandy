import Image from "next/image";
import { FBC_SOLLENTUNA, getTeamBrand, type TeamBrand } from "@/features/teams/team-brand";

type LogoSize = "sm" | "md" | "lg";

const sizes: Record<LogoSize, { box: string; pixels: number }> = {
  sm: { box: "size-10", pixels: 40 },
  md: { box: "size-12", pixels: 48 },
  lg: { box: "size-16", pixels: 64 },
};

function Logo({ brand, fallbackName, size = "sm" }: { brand: TeamBrand | null; fallbackName: string; size?: LogoSize }) {
  const dimensions = sizes[size];
  return <span aria-hidden="true" className={`${dimensions.box} flex shrink-0 items-center justify-center overflow-hidden rounded-full bg-white p-1 shadow-sm ring-1 ring-slate-200`}>
    {brand ? <Image src={brand.logoSrc} alt="" width={dimensions.pixels} height={dimensions.pixels} className="size-full object-contain" /> : <span className="text-xs font-bold uppercase text-slate-500">{fallbackName.trim().slice(0, 2)}</span>}
  </span>;
}

export function OpponentLabel({ opponent, size = "sm", className = "" }: { opponent: string; size?: LogoSize; className?: string }) {
  return <span className={`flex min-w-0 items-center gap-3 ${className}`}><Logo brand={getTeamBrand(opponent)} fallbackName={opponent} size={size} /><span className="min-w-0 truncate">{opponent}</span></span>;
}

export function MatchupLabel({ opponent }: { opponent: string }) {
  return <span className="flex min-w-0 items-center gap-3"><Logo brand={FBC_SOLLENTUNA} fallbackName="FBC" size="lg" /><span className="min-w-0 break-words text-center">FBC vs. {opponent}</span><Logo brand={getTeamBrand(opponent)} fallbackName={opponent} size="lg" /></span>;
}
