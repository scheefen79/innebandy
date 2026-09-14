"use client";

import Link from "next/link";
import { useState } from "react";

type MobileNavigationItem = { href: string; label: string };

export function MobileNavigation({ items, currentItem }: { items: readonly MobileNavigationItem[]; currentItem: string }) {
  const [open, setOpen] = useState(false);
  return <div className="relative md:hidden">
    <button type="button" aria-label={open ? "Stäng meny" : "Öppna meny"} aria-expanded={open} aria-controls="mobile-navigation" onClick={() => setOpen((value) => !value)} className="flex min-h-11 min-w-11 items-center justify-center rounded-xl text-blue-100 hover:bg-white/10 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white">
      <svg aria-hidden="true" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" d="M4 7h16M4 12h16M4 17h16" /></svg>
    </button>
    {open ? <nav id="mobile-navigation" aria-label="Huvudnavigation" className="absolute left-0 top-12 z-50 w-64 overflow-hidden rounded-2xl bg-white p-2 text-slate-950 shadow-xl ring-1 ring-slate-900/10"><ul className="space-y-1">{items.map((item) => <li key={item.label}><Link aria-current={item.label === currentItem ? "page" : undefined} href={item.href} onClick={() => setOpen(false)} className={`block rounded-xl px-4 py-3 text-sm font-semibold ${item.label === currentItem ? "bg-blue-50 text-blue-800" : "text-slate-700 hover:bg-slate-50"}`}>{item.label}</Link></li>)}</ul></nav> : null}
  </div>;
}
