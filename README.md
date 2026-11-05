# boosh packs

The catalog of optional packs for [boosh](https://github.com/Bopster410/booosh) (a minimal Ghostty + fish setup).
One folder per pack; `./pack add NAME` in boosh downloads it from here and installs it.

```
NAME/
  pack.conf            DESCRIPTION=..., API=1, TOOL=cmd|brew pkg|apt pkg|description (optional tools)
  fish.fish            linked to ~/.config/fish/conf.d/pack-NAME.fish
  conf.d/ functions/ completions/ themes/     the fisher layout, linked file by file into ~/.config/fish/
  gitconfig[.tool]     pulled into git with one include.path line (the .tool one only while that tool exists)
  extras/PART/         an optional part: ./pack add NAME --PART
```

A pack is plain text and runs in every fish session: read it before you install it (`./pack show NAME`).
For reproducible installs pin this repository to a commit in boosh's `packs.conf`.

## Packs

| Pack | What it is |
|---|---|
| `git` | abbreviations (`gst`, `gd`, `gcm`, `gl`, `gla`, `gundo`, `gcam`...), `gsync`, safe git settings, git info in the boosh prompt. Optional part `--tag`: `gtag patch\|minor\|major`. |
| `docker` | abbreviations for docker and compose. |

## Developing and testing

Try a change without publishing it: point boosh at your checkout.

```bash
BOOSH_CATALOG=~/booosh-packs ./pack add git --tag     # run in the boosh checkout
bash tests/packs.sh                                   # all pack tests, in a throw-away $HOME
BOOSH_TEST_PTY=1 bash tests/packs.sh                  # also the asynchronous prompt repaint (Linux)
```

The tests need `fish` and `git` for most checks, and a checkout of boosh (`BOOSH_BASE`, or `../dotfiles`, `../booosh`,
`./base`) for the ones that install a pack or use the boosh prompt.
