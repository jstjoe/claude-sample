# Personal Claude skills

Canonical copies of my personal [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills),
version-controlled here so they stay in sync across machines and projects.

## Layout

Each skill is a directory holding a `SKILL.md` (plus any supporting files):

```
skills/
  make-demos/
    SKILL.md
  vhs-demos/
    SKILL.md
    config.tape
    demo.example.tape
    mutate.sh
  playwright-demos/
    SKILL.md
    playwright-record.mjs
    flow.example.mjs
  demo-media/
    SKILL.md
  remotion-best-practices/
    SKILL.md
    rules/
```

## Use on a new machine

Clone the repo, then run the installer to symlink every skill into
`~/.claude/skills/`:

```bash
git clone git@github.com:jstjoe/claude-sample.git
cd claude-sample
./install.sh
```

The installer symlinks (does not copy), so editing a skill here — or letting
Claude edit it — updates the live version immediately, and `git` tracks the
change. Re-run `./install.sh` any time you add a new skill.

## Skills

See **[../docs/automated-demos.md](../docs/automated-demos.md)** for how the demo
skills fit together and which one to reach for.

- **make-demos** — the **front door**: one drivable skill that bootstraps the
  toolchain, then routes to the recorders below (terminal→VHS, browser→Playwright,
  edit/redact→demo-media, brand→Remotion) and carries the end-to-end recipes. Start
  here when the demo spans record → edit → brand, or you don't yet know which tool.
- **vhs-demos** — record reproducible terminal demos as GIF/MP4/WebM from a
  declarative `.tape` script with [VHS](https://github.com/charmbracelet/vhs).
  Ships a shared `config.tape`, a `demo.example.tape` template, and `mutate.sh`
  (colour PII red / tokens green / redact secrets on camera).
- **playwright-demos** — local browser automation for demo capture: a turnkey
  `playwright-record.mjs` that records a scripted flow to video (animated cursor,
  action/chapter overlays via Playwright's screencast API), plus screenshots and
  `codegen` authoring. Ships a `flow.example.mjs` template.
- **demo-media** — record, edit, compress, and annotate demo videos and
  screenshots with ffmpeg and ImageMagick (GIFs, MP4 compression, cropping,
  annotation, PII redaction).
- **remotion-best-practices** — domain knowledge for building videos in
  React/TypeScript with [Remotion](https://remotion.dev) and rendering to MP4:
  animation with `interpolate`/`spring`, scene sequencing, transitions,
  captions, audio, fonts, effects, and dynamic duration. Pairs well with
  **demo-media** — record a raw demo, then wrap it in branded titles/motion.

### Vendored skills

`remotion-best-practices` is vendored from the upstream
[remotion-dev/skills](https://github.com/remotion-dev/skills) repo, not authored
here. Don't hand-edit it — refresh from upstream instead:

```bash
pnpm dlx skills@latest add remotion-dev/skills -y   # re-pull latest into ~/.agents/skills
cp -RL ~/.claude/skills/remotion-best-practices skills/   # re-vendor into this repo
```

Like any third-party skill, it runs with full agent permissions — review before
use.
