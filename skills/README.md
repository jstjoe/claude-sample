# Personal Claude skills

Canonical copies of my personal [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills),
version-controlled here so they stay in sync across machines and projects.

## Layout

Each skill is a directory holding a `SKILL.md` (plus any supporting files):

```
skills/
  demo-media/
    SKILL.md
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

- **demo-media** — record, edit, compress, and annotate demo videos and
  screenshots with ffmpeg and ImageMagick (GIFs, MP4 compression, cropping,
  annotation, PII redaction).
