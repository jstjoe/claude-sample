#!/usr/bin/env node
// playwright-record.mjs — turnkey browser-demo recorder.
//
// Launches Chromium (headed, paced with slowMo so it reads on camera), records
// the session to video, runs a *scripted* flow you supply, then flushes +
// optionally transcodes the raw .webm into a shareable MP4 and a snappy GIF.
// One command, walk away — the browser equivalent of the demo-media
// `record-demo.sh` terminal recorder.
//
// By default it records with Playwright's **screencast** API (v1.59+): an
// animated mouse cursor, per-action title overlays, and chapter cards — the
// on-camera affordances that make an automated run look narrated. Pass --basic
// to fall back to the plain `recordVideo` context option (no cursor/overlays).
//
// The recorder is PROJECT-AGNOSTIC: the actions come from a --flow module you
// point it at, so the same script records any web app.
//
//   node playwright-record.mjs --flow demo/flow.mjs --mp4 --gif
//   node playwright-record.mjs --flow demo/flow.mjs --device "iPhone 15" --mp4
//   node playwright-record.mjs --url https://example.com --shot hero.png   # just screenshot
//   node playwright-record.mjs --flow demo/flow.mjs --headless             # CI / no window
//   node playwright-record.mjs --flow demo/flow.mjs --basic                # plain recordVideo
//
// The flow module default-exports an async function it receives a context:
//   export default async function demo({ page, context, step, chapter, shot, log, args }) {
//     await page.goto(args.url ?? 'http://localhost:3000');
//     await chapter('Dashboard', { description: 'Live widget metrics' });
//     await step('Open the dashboard', async () => { await page.getByRole('link', {name:'Dashboard'}).click(); });
//     await step('Search',            async () => { await page.getByPlaceholder('Search').fill('widgets'); await page.keyboard.press('Enter'); });
//     await shot('results');   // demo-out/<stamp>-results.png
//   }
// See flow.example.mjs beside this script for a full template.

import { chromium, devices } from 'playwright';
import { spawnSync } from 'node:child_process';
import { mkdirSync, existsSync, renameSync, readdirSync, statSync, rmSync } from 'node:fs';
import { resolve, join, isAbsolute } from 'node:path';
import { pathToFileURL } from 'node:url';

// ---- args -----------------------------------------------------------------
function parseArgs(argv) {
  const a = { out: 'demo-out', size: '1280x800', slowmo: 400, scale: 1, pause: 600,
              headless: false, basic: false, cursor: 'pointer', mp4: false, gif: false,
              keepWebm: true, gifWidth: 1000, gifFps: 12 };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i], next = () => argv[++i];
    switch (k) {
      case '--flow':      a.flow = next(); break;
      case '--url':       a.url = next(); break;
      case '--out':       a.out = next(); break;
      case '--size':      a.size = next(); break;         // WxH, e.g. 1440x900
      case '--slowmo':    a.slowmo = +next(); break;       // ms between actions
      case '--scale':     a.scale = +next(); break;        // deviceScaleFactor (2 = retina screenshots)
      case '--pause':     a.pause = +next(); break;        // ms held after each step()
      case '--device':    a.device = next(); break;        // e.g. "iPhone 15"
      case '--shot':      a.shot = next(); break;          // screenshot-only mode: output filename
      case '--tag':       a.tag = next(); break;           // label appended to output names
      case '--cursor':    a.cursor = next(); break;        // 'pointer' (default) | 'none'
      case '--headless':  a.headless = true; break;
      case '--headed':    a.headless = false; break;
      case '--basic':     a.basic = true; break;           // recordVideo instead of screencast
      case '--mp4':       a.mp4 = true; break;
      case '--gif':       a.gif = true; break;
      case '--no-webm':   a.keepWebm = false; break;       // delete raw .webm after transcode
      case '-h': case '--help': a.help = true; break;
      default: console.error(`Unknown arg: ${k}`); process.exit(2);
    }
  }
  return a;
}

const HELP = `playwright-record.mjs — record a scripted browser demo to video/screenshots.

  --flow <file>     JS module default-exporting async ({page,context,step,chapter,shot,log,args}) => {}
  --url <url>       passed to the flow as args.url; in --shot mode, the page to open
  --shot <file>     screenshot-only mode (no video): open --url, save <file>, exit
  --out <dir>       output dir (default demo-out)
  --size <WxH>      viewport + video size (default 1280x800)
  --device <name>   emulate a device, e.g. "iPhone 15" (overrides --size)
  --slowmo <ms>     delay between Playwright actions (default 400) — pacing for camera
  --pause <ms>      extra hold after each step() (default 600)
  --scale <n>       deviceScaleFactor for screenshots (default 1; use 2 for retina)
  --cursor <mode>   screencast cursor: pointer (default, animated) | none
  --tag <label>     label appended to output filenames
  --headed|--headless   window on (default) / off (CI)
  --basic           use plain recordVideo (no cursor/action overlays) instead of screencast
  --mp4             also emit a shareable H.264 MP4 (needs ffmpeg)
  --gif             also emit a 2-pass-palette GIF (needs ffmpeg)
  --no-webm         delete the raw .webm after transcoding

Outputs: <out>/<stamp>[-tag].{webm,mp4,gif} and <out>/<stamp>-<name>.png.`;

// ---- helpers --------------------------------------------------------------
function stamp() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${p(d.getMonth()+1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}
function have(bin) { return spawnSync(bin, ['-version'], { stdio: 'ignore' }).status === 0; }
function run(bin, args) {
  const r = spawnSync(bin, args, { stdio: 'inherit' });
  if (r.status !== 0) throw new Error(`${bin} exited ${r.status}`);
}
// webm -> MP4 (H.264, faststart) — the demo-media recipe.
function toMp4(webm, mp4) {
  run('ffmpeg', ['-y', '-i', webm, '-vcodec', 'libx264', '-crf', '23', '-preset', 'slow',
                 '-pix_fmt', 'yuv420p', '-movflags', '+faststart', mp4]);
}
// webm -> GIF (2-pass palette) — the only way to get clean GIFs.
function toGif(webm, gif, { gifWidth, gifFps }) {
  const pal = gif.replace(/\.gif$/, '.palette.png');
  run('ffmpeg', ['-y', '-i', webm, '-vf', `fps=${gifFps},scale=${gifWidth}:-1:flags=lanczos,palettegen`, pal]);
  run('ffmpeg', ['-y', '-i', webm, '-i', pal, '-lavfi',
                 `fps=${gifFps},scale=${gifWidth}:-1:flags=lanczos,paletteuse`, gif]);
  rmSync(pal, { force: true });
}

// ---- main -----------------------------------------------------------------
const args = parseArgs(process.argv.slice(2));
if (args.help) { console.log(HELP); process.exit(0); }

const [w, h] = args.size.split('x').map(Number);
const outDir = resolve(args.out);
mkdirSync(outDir, { recursive: true });
const S = stamp() + (args.tag ? `-${args.tag}` : '');
const webmPath = join(outDir, `${S}.webm`);

const browser = await chromium.launch({ headless: args.headless, slowMo: args.slowmo, args: ['--hide-scrollbars'] });

if (args.device && !devices[args.device]) {
  console.error(`Unknown --device "${args.device}". Try: iPhone 15, Pixel 7, iPad Mini, Desktop Chrome …`);
  await browser.close(); process.exit(2);
}
const base = args.device
  ? devices[args.device]
  : { viewport: { width: w, height: h }, deviceScaleFactor: args.scale };

// ---- screenshot-only mode -------------------------------------------------
if (args.shot) {
  if (!args.url) { console.error('--shot needs --url'); await browser.close(); process.exit(2); }
  const context = await browser.newContext(base);
  const page = await context.newPage();
  await page.goto(args.url, { waitUntil: 'networkidle' });
  const outFile = isAbsolute(args.shot) ? args.shot : join(outDir, args.shot);
  await page.screenshot({ path: outFile, fullPage: true, scale: args.scale > 1 ? 'device' : 'css' });
  console.log(`📸  ${outFile}`);
  await context.close(); await browser.close();
  process.exit(0);
}

// ---- video-recording mode -------------------------------------------------
const useScreencast = !args.basic;
const context = await browser.newContext(
  useScreencast ? base : { ...base, recordVideo: { dir: outDir, size: { width: w, height: h } } });
const page = await context.newPage();

if (useScreencast) {
  // screencast writes straight to our path; annotate = per-action title overlay.
  await page.screencast.start({ path: webmPath, size: { width: w, height: h },
                                annotate: { position: 'top-right', fontSize: 16 } });
  await page.screencast.showActions({ cursor: args.cursor });   // animated pointer + click decorations
}

// helpers handed to the flow: step() paces + narrates, chapter() shows a card, shot() grabs a still.
let n = 0;
const log = (m) => console.log(`   ${m}`);
const step = async (label, fn) => {
  n += 1;
  console.log(`▶  ${n}. ${label}`);
  await fn();
  await page.waitForTimeout(args.pause);
};
const chapter = async (title, opts = {}) => {
  console.log(`▚  ${title}`);
  if (useScreencast) await page.screencast.showChapter(title, opts);
  else await page.waitForTimeout(opts.duration ?? 1500);
};
const shot = async (name) => {
  const f = join(outDir, `${S}-${name}.png`);
  await page.screenshot({ path: f, scale: args.scale > 1 ? 'device' : 'css' });
  console.log(`📸  ${f}`);
  return f;
};

let flowErr;
try {
  if (args.flow) {
    const flowPath = resolve(args.flow);
    if (!existsSync(flowPath)) throw new Error(`--flow file not found: ${flowPath}`);
    const mod = await import(pathToFileURL(flowPath).href);
    const demo = mod.default ?? mod.demo;
    if (typeof demo !== 'function') throw new Error(`${flowPath} must default-export an async function`);
    await demo({ page, context, step, chapter, shot, log, args, devices });
  } else if (args.url) {
    await page.goto(args.url, { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);
  } else {
    throw new Error('Nothing to do: pass --flow <file> or --url <url>. See --help.');
  }
} catch (e) {
  flowErr = e;
  console.error(`\n✗ flow error: ${e.message}`);
}

// Flush the video. screencast.stop() writes to webmPath; recordVideo needs context.close().
let webm = webmPath;
if (useScreencast) {
  try { await page.screencast.stop(); } catch (e) { console.error(`screencast.stop: ${e.message}`); }
  const video = page.video();       // capture before closing, just in case
  await context.close();
  if (!existsSync(webm)) { try { const p = await video?.path(); if (p && existsSync(p)) renameSync(p, webm); } catch {} }
} else {
  const video = page.video();
  await context.close();            // flushes recordVideo
  try {
    const src = await video?.path();
    if (src && existsSync(src)) renameSync(src, webm);
    else webm = null;
  } catch { webm = null; }
}
await browser.close();

// fallback: newest .webm in outDir
if (!webm || !existsSync(webm)) {
  const cands = readdirSync(outDir).filter(f => f.endsWith('.webm')).map(f => join(outDir, f))
    .sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
  webm = cands[0] || null;
  if (webm && webm !== webmPath) { renameSync(webm, webmPath); webm = webmPath; }
}

if (!webm) { console.error('No video produced.'); process.exit(flowErr ? 1 : 2); }
console.log(`\n🎬  ${webm}`);

if ((args.mp4 || args.gif) && !have('ffmpeg')) {
  console.error('ffmpeg not found — skipping MP4/GIF. Install: brew install ffmpeg');
} else {
  if (args.mp4) { const mp4 = webm.replace(/\.webm$/, '.mp4'); toMp4(webm, mp4); console.log(`🎞  ${mp4}`); }
  if (args.gif) { const gif = webm.replace(/\.webm$/, '.gif'); toGif(webm, gif, args); console.log(`🖼  ${gif}`); }
  if (!args.keepWebm && (args.mp4 || args.gif)) { rmSync(webm, { force: true }); console.log(`   (removed raw ${webm})`); }
}

process.exit(flowErr ? 1 : 0);
