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
