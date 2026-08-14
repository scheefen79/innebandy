import type { ReactNode } from "react";

type AppShellProps = {
  children: ReactNode;
};

const navigation = ["Översikt", "Matcher", "Spelare"];

export function AppShell({ children }: AppShellProps) {
  return (
    <div className="min-h-screen bg-[#F5F7FA] pb-20 md:pb-0">
      <header className="bg-[#082B4C] text-white md:hidden">
        <div className="mx-auto max-w-5xl px-4 py-4">
          <p className="text-xs font-medium uppercase tracking-[0.16em] text-blue-200">
            FBC Sollentuna
          </p>
          <p className="mt-1 text-lg font-semibold">P17</p>
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
              {navigation.map((item, index) => (
                <li key={item}>
                  <span
                    aria-current={index === 0 ? "page" : undefined}
                    className={`block rounded-xl px-3 py-3 text-sm font-medium ${
                      index === 0 ? "bg-white text-[#082B4C]" : "text-blue-100"
                    }`}
                  >
                    {item}
                  </span>
                </li>
              ))}
            </ul>
          </nav>
        </aside>

        <main className="w-full px-4 py-6 sm:px-6 md:px-8 md:py-10">{children}</main>
      </div>

      <nav
        aria-label="Huvudnavigation"
        className="fixed inset-x-0 bottom-0 border-t border-slate-200 bg-white md:hidden"
      >
        <ul className="mx-auto grid max-w-lg grid-cols-3">
          {navigation.map((item, index) => (
            <li key={item}>
              <span
                aria-current={index === 0 ? "page" : undefined}
                className={`flex min-h-16 items-center justify-center px-2 text-xs font-semibold ${
                  index === 0 ? "text-blue-700" : "text-slate-500"
                }`}
              >
                {item}
              </span>
            </li>
          ))}
        </ul>
      </nav>
    </div>
  );
}
