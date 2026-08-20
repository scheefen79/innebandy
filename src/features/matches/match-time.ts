const stockholmParts = new Intl.DateTimeFormat("sv-SE", {
  timeZone: "Europe/Stockholm",
  year: "numeric", month: "2-digit", day: "2-digit",
  hour: "2-digit", minute: "2-digit", hourCycle: "h23",
});

export type LocalMatchTimeResult =
  | { ok: true; value: string }
  | { ok: false; reason: "invalid" | "nonexistent" | "ambiguous" };

function formattedParts(timestamp: number) {
  return Object.fromEntries(stockholmParts.formatToParts(timestamp).map((part) => [part.type, part.value]));
}

export function stockholmLocalToUtc(date: string, time: string): LocalMatchTimeResult {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  const timeMatch = /^(\d{2}):(\d{2})$/.exec(time);
  if (!match || !timeMatch) return { ok: false, reason: "invalid" };

  const [, year, month, day] = match;
  const [, hour, minute] = timeMatch;
  const utcLike = Date.UTC(+year, +month - 1, +day, +hour, +minute);
  const candidates = new Set<number>();

  for (let offsetMinutes = 0; offsetMinutes <= 180; offsetMinutes += 30) {
    const candidate = utcLike - offsetMinutes * 60_000;
    const parts = formattedParts(candidate);
    if (parts.year === year && parts.month === month && parts.day === day && parts.hour === hour && parts.minute === minute) {
      candidates.add(candidate);
    }
  }

  if (candidates.size === 0) return { ok: false, reason: "nonexistent" };
  if (candidates.size > 1) return { ok: false, reason: "ambiguous" };
  return { ok: true, value: new Date([...candidates][0]).toISOString() };
}

export function formatStockholmDateTime(value: string) {
  return new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Europe/Stockholm", dateStyle: "long", timeStyle: "short",
  }).format(new Date(value));
}
