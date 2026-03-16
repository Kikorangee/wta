import fs from "node:fs/promises";

const VIMEO_TOKEN = process.env.VIMEO_TOKEN;
if (!VIMEO_TOKEN) {
  throw new Error("Missing VIMEO_TOKEN env var. In PowerShell: $env:VIMEO_TOKEN='...'");
}

// Change this later if you want Album/Folder-only:
const SOURCE_ENDPOINT = "https://api.vimeo.com/me/videos";

const CATEGORY_ORDER = [
  "Tracking & Fleet",
  "Reporting",
  "Initial Setup",
  "General",
  "Orders & Workflow",
  "Uncategorized",
];

function normalizeTag(tag) {
  return String(tag || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "-");
}

function getVideoIdFromUri(uri) {
  const m = String(uri || "").match(/\/videos\/(\d+)/);
  return m ? m[1] : "";
}

function pickThumb(pictures) {
  const sizes = pictures?.sizes || [];
  const best = sizes.find(s => s.width >= 640) || sizes[sizes.length - 1];
  return best?.link || "";
}

function toMMSS(seconds) {
  if (typeof seconds !== "number" || !Number.isFinite(seconds)) return "";
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}

function categorizeByTags(tags) {
  const set = new Set((tags || []).map(normalizeTag));

  if (set.has("tracking") || set.has("fleet") || set.has("tracking-and-fleet")) return "Tracking & Fleet";
  if (set.has("reporting")) return "Reporting";
  if (set.has("initial-setup") || set.has("setup") || set.has("initial")) return "Initial Setup";
  if (set.has("general")) return "General";
  if (set.has("orders") || set.has("workflow") || set.has("orders-and-workflow")) return "Orders & Workflow";

  return "Uncategorized";
}

async function vimeoGet(url) {
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${VIMEO_TOKEN}`,
      Accept: "application/vnd.vimeo.*+json;version=3.4",
    },
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`Vimeo API error ${res.status} for ${url}\n${body}`);
  }
  return res.json();
}

async function main() {
  const categories = Object.fromEntries(CATEGORY_ORDER.map(k => [k, []]));

  let next = `${SOURCE_ENDPOINT}?per_page=100&fields=uri,name,description,duration,pictures,modified_time,created_time,tags`;

  while (next) {
    const page = await vimeoGet(next);

    for (const v of page.data || []) {
      const id = getVideoIdFromUri(v.uri);
      if (!id) continue;

      const rawTags = (v.tags || []).map(t => t?.tag).filter(Boolean);
      const category = categorizeByTags(rawTags);

      categories[category].push({
        id,
        title: v.name || "",
        description: v.description || "",
        thumb: pickThumb(v.pictures),
        duration_seconds: v.duration ?? null,
        duration_label: toMMSS(v.duration),
        tags: rawTags.map(normalizeTag),
        created_time: v.created_time || null,
        modified_time: v.modified_time || null,
      });
    }

    next = page.paging?.next ? `https://api.vimeo.com${page.paging.next}` : null;
  }

  // Sort each category by modified_time desc (optional)
  for (const key of Object.keys(categories)) {
    categories[key].sort((a, b) => String(b.modified_time).localeCompare(String(a.modified_time)));
  }

  const out = {
    generated_at: new Date().toISOString(),
    source: SOURCE_ENDPOINT,
    categories,
  };

  await fs.mkdir("data", { recursive: true });
  await fs.writeFile("data/videos.json", JSON.stringify(out, null, 2), "utf8");
  console.log("Wrote data/videos.json");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});