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
              headless: false, basic: false, cursor: 'pointer', hold: 1400, mp4: false, gif: false,
              keepWebm: true, gifWidth: 0, gifFps: 20, quality: 100, crf: 18, pixfmt: 'yuv420p',
              chapterBlur: false };
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
      case '--hold':      a.hold = +next(); break;         // ms the cursor/action label lingers (default 1400)
      case '--headless':  a.headless = true; break;
      case '--headed':    a.headless = false; break;
      case '--basic':     a.basic = true; break;           // recordVideo instead of screencast
      case '--mp4':       a.mp4 = true; break;
      case '--gif':       a.gif = true; break;
      case '--no-webm':   a.keepWebm = false; break;       // delete raw .webm after transcode
      case '--gif-fps':   a.gifFps = +next(); break;       // GIF frame rate (default 20)
      case '--gif-width': a.gifWidth = +next(); break;     // GIF width px; 0 = native, no downscale (default)
      case '--quality':   a.quality = +next(); break;      // screencast frame quality 1-100 (default 100)
      case '--crf':       a.crf = +next(); break;          // H.264 quality, lower = sharper/bigger (default 18)
      case '--pix-fmt':   a.pixfmt = next(); break;        // yuv420p (compat, default) | yuv444p (sharper color)
      case '--chapter-blur': a.chapterBlur = true; break;  // use Playwright's blurred full-page chapter card
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
  --quality <1-100> screencast frame quality (default 100 — higher = sharper text/lines)
  --chapter-blur    use Playwright's blurred full-page chapter card (default: clean, no page blur)
  --mp4             also emit a shareable H.264 MP4 (needs ffmpeg)
  --crf <n>         MP4 H.264 quality, lower = sharper/bigger (default 18)
  --pix-fmt <fmt>   MP4 pixel format: yuv420p (compat, default) | yuv444p (sharper colored edges)
  --gif             also emit a 2-pass-palette GIF (needs ffmpeg)
  --gif-fps <n>     GIF frame rate (default 20)
  --gif-width <px>  GIF width; 0 = native, no downscale (default). Small README GIF: try 800
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
function toMp4(webm, mp4, { crf, pixfmt }) {
  run('ffmpeg', ['-y', '-i', webm, '-vcodec', 'libx264', '-crf', String(crf), '-preset', 'slow',
                 '-pix_fmt', pixfmt, '-movflags', '+faststart', mp4]);
}
// webm -> GIF (2-pass palette) — the only way to get clean GIFs. gifWidth 0 = keep
// native width (no downscale); stats_mode=diff + sierra2_4a dither keep text/lines crisp.
function toGif(webm, gif, { gifWidth, gifFps }) {
  const pal = gif.replace(/\.gif$/, '.palette.png');
  const scale = gifWidth > 0 ? `scale=${gifWidth}:-1:flags=lanczos,` : '';
  run('ffmpeg', ['-y', '-i', webm, '-vf', `fps=${gifFps},${scale}palettegen=stats_mode=diff`, pal]);
  run('ffmpeg', ['-y', '-i', webm, '-i', pal, '-lavfi',
                 `fps=${gifFps},${scale}paletteuse=dither=sierra2_4a`, gif]);
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

// An always-visible cursor that follows the mouse with a CSS glide + a click
// pulse. Injected into the page so it records reliably as plain DOM — the native
// screencast pointer only appears at discrete actions, so it reads as teleporting.
const CURSOR_SCRIPT = () => {
  const mount = () => {
    if (document.getElementById('__demoCursor')) return;
    const st = document.createElement('style');
    st.textContent = `@keyframes __demoPulse{from{opacity:.55;transform:translate(-50%,-50%) scale(.3)}to{opacity:0;transform:translate(-50%,-50%) scale(1)}}`;
    document.head.appendChild(st);
    const c = document.createElement('div');
    c.id = '__demoCursor';
    c.innerHTML = '<svg width="26" height="26" viewBox="0 0 24 24" style="filter:drop-shadow(0 1px 2px rgba(0,0,0,.55))"><path d="M0 0 L0 17 L4.7 12.7 L7.6 19.2 L10 18.1 L7.1 11.7 L12.6 11.4 Z" fill="#fff" stroke="#111" stroke-width="1.2" stroke-linejoin="round"/></svg>';
    const GLIDE = 240;   // ms; keep in sync with the pulse delay below
    Object.assign(c.style, { position: 'fixed', left: '0', top: '0', zIndex: '2147483647',
      pointerEvents: 'none', transition: `transform ${GLIDE}ms cubic-bezier(.22,.61,.36,1)`,
      transform: 'translate(-60px,-60px)', willChange: 'transform' });
    document.body.appendChild(c);
    addEventListener('mousemove', (e) => { c.style.transform = `translate(${e.clientX}px, ${e.clientY}px)`; }, true);
    // The cursor glides for GLIDE ms, so its VISUAL position lags the real one. Delay the
    // click pulse by GLIDE so it blooms exactly as the cursor lands — not before it arrives.
    addEventListener('mousedown', (e) => {
      const x = e.clientX, y = e.clientY;
      setTimeout(() => {
        const p = document.createElement('div');
        Object.assign(p.style, { position: 'fixed', left: x + 'px', top: y + 'px',
          width: '42px', height: '42px', border: '3px solid #8b6dff', borderRadius: '50%',
          zIndex: '2147483646', pointerEvents: 'none', animation: '__demoPulse .45s ease-out forwards' });
        document.body.appendChild(p);
        setTimeout(() => p.remove(), 500);
      }, GLIDE);
    }, true);
  };
  if (document.body) mount(); else addEventListener('DOMContentLoaded', mount);
};

if (useScreencast) {
  // screencast writes straight to our path; annotate = per-action title overlay.
  await page.screencast.start({ path: webmPath, size: { width: w, height: h }, quality: args.quality,
                                annotate: { position: 'top-right', fontSize: 16, duration: args.hold } });
  // No showActions(): its native red click marker fires at the true mouse point,
  // which leads our gliding cursor and reads as a click before arrival. Titles come
  // from start({annotate}); the pointer + click pulse are our injected cursor.
  if (args.cursor !== 'none') await page.addInitScript(CURSOR_SCRIPT);   // runs on the flow's goto
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
  if (!useScreencast) { await page.waitForTimeout(opts.duration ?? 1500); return; }
  if (args.chapterBlur) { await page.screencast.showChapter(title, opts); return; }
  // Default: a clean centered card via showOverlay — NO full-page backdrop blur. Playwright's
  // showChapter blurs the whole page, which softens every frame under video compression; this
  // keeps the page behind sharp. Escape the caller's text before injecting it as HTML.
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const dur = opts.duration ?? 2000;
  const desc = opts.description
    ? `<div style="margin-top:8px;font-size:18px;font-weight:400;opacity:.82">${esc(opts.description)}</div>` : '';
  const ov = await page.screencast.showOverlay(`
    <div style="position:fixed;inset:0;display:flex;align-items:center;justify-content:center;pointer-events:none">
      <div style="padding:22px 36px;border-radius:16px;background:rgba(17,17,20,.9);
        box-shadow:0 14px 44px rgba(0,0,0,.34);text-align:center;color:#fff;
        font-family:system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;-webkit-font-smoothing:antialiased">
        <div style="font-size:30px;font-weight:650;letter-spacing:-.01em">${esc(title)}</div>
        ${desc}
      </div>
    </div>`);
  await page.waitForTimeout(dur);
  try { await ov?.dispose(); } catch {}
};
const shot = async (name) => {
  const f = join(outDir, `${S}-${name}.png`);
  await page.screenshot({ path: f, scale: args.scale > 1 ? 'device' : 'css' });
  console.log(`📸  ${f}`);
  return f;
};
// move(): glide the cursor to a Locator (or {x,y}) in steps so the travel is visible
// on camera, not a teleport. The screencast pointer follows the mouse.
const move = async (target, { steps = 4 } = {}) => {
  let x, y;
  if (target && typeof target.boundingBox === 'function') {
    const b = await target.boundingBox();
    if (!b) throw new Error('move(): target has no bounding box (not visible)');
    x = b.x + b.width / 2; y = b.y + b.height / 2;
  } else { ({ x, y } = target); }
  await page.mouse.move(x, y, { steps });
  return { x, y };
};

let flowErr;
try {
  if (args.flow) {
    const flowPath = resolve(args.flow);
    if (!existsSync(flowPath)) throw new Error(`--flow file not found: ${flowPath}`);
    const mod = await import(pathToFileURL(flowPath).href);
    const demo = mod.default ?? mod.demo;
    if (typeof demo !== 'function') throw new Error(`${flowPath} must default-export an async function`);
    await demo({ page, context, step, chapter, shot, move, log, args, devices });
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
  if (args.mp4) { const mp4 = webm.replace(/\.webm$/, '.mp4'); toMp4(webm, mp4, args); console.log(`🎞  ${mp4}`); }
  if (args.gif) { const gif = webm.replace(/\.webm$/, '.gif'); toGif(webm, gif, args); console.log(`🖼  ${gif}`); }
  if (!args.keepWebm && (args.mp4 || args.gif)) { rmSync(webm, { force: true }); console.log(`   (removed raw ${webm})`); }
}

process.exit(flowErr ? 1 : 0);
