import type { ReactNode } from "react";
import Link from "next/link";

type AppShellProps = {
  children: ReactNode;
  currentItem?: "Kommande" | "Träningar" | "Matcher" | "Spelare";
};

const navigation = [
  { href: "/", label: "Kommande" },
  { href: "/trainings", label: "Träningar" },
  { href: "/matches", label: "Matcher" },
  { href: "/players", label: "Spelare" },
] as const;

export function AppShell({ children, currentItem = "Kommande" }: AppShellProps) {
  return (
    <div className="min-h-screen bg-[#F5F7FA] pb-20 md:pb-0">
      <header className="bg-[#082B4C] text-white md:hidden">
        <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-4">
          <div>
            <p className="text-xs font-medium uppercase tracking-[0.16em] text-blue-200">
              FBC Sollentuna
            </p>
            <p className="mt-1 text-lg font-semibold">P17</p>
          </div>
          <form action="/auth/logout" method="post">
            <button
              className="min-h-11 rounded-xl px-3 text-sm font-semibold text-blue-100 hover:bg-white/10 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
              type="submit"
            >
              Logga ut
            </button>
          </form>
        </div>
      </header>

      <div className="mx-auto grid min-h-screen max-w-6xl md:grid-cols-[220px_1fr]">
        <aside className="hidden bg-[#082B4C] px-5 py-8 text-white md:block">
          <p className="text-xs font-medium uppercase tracking-[0.16em] text-blue-200">
            FBC Sollentuna
          </p>
          <p className="mt-1 text-xl font-semibold">P17</p>
          <nav aria-label="Huvudnavigation" className="mt-10">
            <ul className="space-y-2">
              {navigation.map((item) => (
                <li key={item.label}>
                  <Link
                    aria-current={item.label === currentItem ? "page" : undefined}
                    href={item.href}
                    className={`block rounded-xl px-3 py-3 text-sm font-medium ${
                      item.label === currentItem ? "bg-white text-[#082B4C]" : "text-blue-100 hover:bg-white/10"
                    }`}
                  >
                    {item.label}
                  </Link>
                </li>
              ))}
            </ul>
          </nav>
          <form action="/auth/logout" className="mt-10" method="post">
            <button
              className="min-h-11 w-full rounded-xl border border-blue-300/30 px-3 text-sm font-semibold text-blue-100 hover:bg-white/10 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
              type="submit"
            >
              Logga ut
            </button>
          </form>
        </aside>

        <main className="min-w-0 w-full px-4 py-6 sm:px-6 md:px-8 md:py-10">{children}</main>
      </div>

      <nav
        aria-label="Huvudnavigation"
        className="fixed inset-x-0 bottom-0 border-t border-slate-200 bg-white md:hidden"
      >
        <ul className="mx-auto grid max-w-lg grid-cols-4">
          {navigation.map((item) => (
            <li key={item.label}>
              <Link
                aria-current={item.label === currentItem ? "page" : undefined}
                href={item.href}
                className={`flex min-h-16 items-center justify-center px-2 text-xs font-semibold ${
                  item.label === currentItem ? "text-blue-700" : "text-slate-500"
                }`}
              >
                {item.label}
              </Link>
            </li>
          ))}
        </ul>
      </nav>
    </div>
  );
}
