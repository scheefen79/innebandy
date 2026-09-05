import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

const sourceOrigin = "https://innebandy.se";
const archiveUrl = `${sourceOrigin}/ovningsbanken`;
const outputPath = resolve(process.argv[2] ?? "content/ovningsbanken-exercise-catalog.json");
const pauseMs = 350;
const concurrency = 3;

const namedEntities = { amp: "&", apos: "'", quot: "\"", lt: "<", gt: ">", nbsp: " " };

function decodeHtml(value) {
  return value
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCodePoint(Number.parseInt(code, 16)))
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number.parseInt(code, 10)))
    .replace(/&([a-z]+);/gi, (_, name) => namedEntities[name.toLowerCase()] ?? `&${name};`);
}

function text(value) {
  return decodeHtml(value.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim());
}

function attribute(fragment, name) {
  const match = fragment.match(new RegExp(`${name}=["']([^"']+)["']`, "i"));
  return match ? decodeHtml(match[1]) : null;
}

function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

function absoluteUrl(value) {
  return value ? new URL(decodeHtml(value), sourceOrigin).href : null;
}

function extractCategory(page, className) {
  const section = page.match(new RegExp(`<div[^>]*${className}[\\s\\S]*?(?=<div[^>]*exercise-category--|<div[^>]*class="[^"]*exercise-preamble__|<div[^>]*class="[^"]*exercise-details|</section>)`, "i"))?.[0] ?? "";
  return unique([...section.matchAll(/<span[^>]*status-button[^>]*>([\s\S]*?)<\/span>/gi)].map(match => text(match[1])));
}

function extractTitle(page) {
  const match = page.match(/<h1[^>]*exercise-preamble__heading[^>]*>([\s\S]*?)<\/h1>/i) ?? page.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
  return match ? text(match[1]) : null;
}

function extractSummary(page) {
  const region = page.match(/exercise-preamble__categorys[\s\S]{0,9000}/i)?.[0] ?? "";
  const paragraphs = [...region.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/gi)].map(match => text(match[1])).filter(Boolean);
  return paragraphs[0] ?? null;
}

function extractImageUrl(page) {
  const picture = page.match(/<picture class="thumbnail-container">([\s\S]*?)<\/picture>/i)?.[1] ?? "";
  return absoluteUrl(attribute(picture, "srcset") ?? attribute(picture, "src"));
}

function extractVideoUrl(page) {
  const video = page.match(/<video[^>]*exercise-video[\s\S]*?<\/video>/i)?.[0] ?? page.match(/<video[\s\S]*?<\/video>/i)?.[0] ?? "";
  return absoluteUrl(attribute(video, "src"));
}

function extractLevels(page) {
  return unique([...page.matchAll(/<title class="(?:gron|bla|rod|svart)[^"]*">([\s\S]*?)<\/title>/gi)].map(match => text(match[1])));
}

async function fetchText(url) {
  const response = await fetch(url, { headers: { "user-agent": "FBC-Sollentuna-P17 exercise catalog audit (contact: local team administrator)" } });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  return response.text();
}

async function mapWithConcurrency(values, worker) {
  const results = new Array(values.length);
  let cursor = 0;
  await Promise.all(Array.from({ length: Math.min(concurrency, values.length) }, async () => {
    while (true) {
      const index = cursor++;
      if (index >= values.length) return;
      results[index] = await worker(values[index], index);
    }
  }));
  return results;
}

const archive = await fetchText(archiveUrl);
const exerciseUrls = [...new Set([...archive.matchAll(/href="(\/ovningsbanken\/[a-z0-9-]+)"/gi)].map(match => absoluteUrl(match[1])))]
  .filter(url => url !== archiveUrl)
  .sort((left, right) => left.localeCompare(right, "sv"));

if (exerciseUrls.length === 0) throw new Error("Hittade inga övningar i Övningsbanken.");

const failures = [];
const exercises = (await mapWithConcurrency(exerciseUrls, async (sourceUrl, index) => {
  if (index > 0) await new Promise(resolvePause => setTimeout(resolvePause, pauseMs));
  try {
    const page = await fetchText(sourceUrl);
    const title = extractTitle(page);
    if (!title) throw new Error("Saknar titel");
    return {
      id: new URL(sourceUrl).pathname.split("/").at(-1),
      title,
      sourceUrl,
      sourceImageUrl: extractImageUrl(page),
      sourceVideoUrl: extractVideoUrl(page),
      summary: extractSummary(page),
      themes: extractCategory(page, "exercise-category--theme"),
      skills: extractCategory(page, "exercise-category--skill"),
      levels: extractLevels(page)
    };
  } catch (error) {
    failures.push({ sourceUrl, error: error instanceof Error ? error.message : String(error) });
    return null;
  }
})).filter(Boolean);

const catalog = {
  schemaVersion: 1,
  collectedAt: new Date().toISOString(),
  source: {
    name: "Svensk Innebandys Övningsbank",
    archiveUrl,
    attribution: "Övningarnas originalkälla är Svensk Innebandys Övningsbank. Appen lagrar endast katalogmetadata och länkar till originalet."
  },
  exercises,
  failures
};

await mkdir(dirname(outputPath), { recursive: true });
await writeFile(outputPath, `${JSON.stringify(catalog, null, 2)}\n`, "utf8");

console.log(JSON.stringify({ discovered: exerciseUrls.length, collected: exercises.length, failures: failures.length, outputPath }, null, 2));
if (failures.length > 0) process.exitCode = 1;
