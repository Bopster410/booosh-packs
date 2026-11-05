#!/usr/bin/env bash
# Tests for the packs of this catalog. Everything runs against a throw-away $HOME; nothing outside it is touched.
#   bash tests/packs.sh                      # run all
#   BOOSH_BASE=/path/to/boosh bash tests/packs.sh
#   BOOSH_TEST_PTY=1 bash tests/packs.sh     # also checks the asynchronous prompt repaint in a live fish (Linux)
# Needs: bash, git, awk, sed. `fish` is optional (checks that need it are skipped). The checks that install a pack
# or use the boosh prompt need a checkout of boosh (https://github.com/Bopster410/booosh): BOOSH_BASE, or ../dotfiles,
# ../booosh or ./base next to / inside this repository; without it they are skipped.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '        %s\n' "$2"; }
check() { # check "name" command...   (passes when the command succeeds)
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name"; fi
}
has() { grep -qE -- "$2" <<< "$1"; }   # has "$text" "regex"

new_home() { T="$(mktemp -d "${TMPDIR:-/tmp}/boosh-packs-test.XXXXXX")"; export HOME="$T" XDG_CONFIG_HOME="$T/.config" XDG_DATA_HOME="$T/.local/share"; unset GIT_CONFIG_GLOBAL; }
cleanup() { [ -z "${T:-}" ] || rm -rf "$T" 2>/dev/null || { sleep 1; rm -rf "$T" 2>/dev/null; } || true; }
trap cleanup EXIT

BASE=""
for c in "${BOOSH_BASE:-}" "$ROOT/../dotfiles" "$ROOT/../booosh" "$ROOT/base"; do
  if [ -n "$c" ] && [ -x "$c/pack" ] && [ -x "$c/install.sh" ]; then BASE="$(cd "$c" && pwd)"; break; fi
done
export BOOSH_CATALOG="$ROOT"   # this repository is the catalog: the packs under test are the ones in the working tree
export BOOSH_BREW_CANDIDATES=""   # never touch a real Homebrew
# a real delta / lazygit on this machine would change what the tests see: drop the PATH entries that hold one
path_without() { local d c skip out="" IFS=:; for d in $PATH; do skip=0; for c in "$@"; do case "$d" in /usr/bin|/bin|/usr/local/bin) ;; *) [ -x "$d/$c" ] && skip=1 ;; esac; done; [ "$skip" = 1 ] || out="${out:+$out:}$d"; done; echo "$out"; }
PATH="$(path_without delta lazygit lazydocker)"
HAVE_FISH=0; command -v fish >/dev/null 2>&1 && HAVE_FISH=1
HAVE_GIT=0; command -v git >/dev/null 2>&1 && HAVE_GIT=1
[ -n "$BASE" ] && echo "boosh checkout: $BASE" || echo "no boosh checkout found (set BOOSH_BASE): the install and prompt checks are skipped"
strip() { sed -E 's/\x1b\][^\x07\x1b]*(\x07|\x1b\\)//g; s/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b\(B//g'; }

echo "== layout and syntax"
for d in "$ROOT"/*/; do
  [ -f "${d}pack.conf" ] || continue
  n="$(basename "$d")"
  check "$n: pack.conf has DESCRIPTION and API" bash -c "grep -q '^DESCRIPTION=.' '${d}pack.conf' && grep -q '^API=[0-9]' '${d}pack.conf'"
done
if [ "$HAVE_FISH" = 1 ]; then
  bad=0; n=0
  while IFS= read -r f; do n=$((n + 1)); out="$(fish --no-execute "$f" 2>&1)" || { bad=$((bad + 1)); echo "        $f: $out"; }; done < <(find "$ROOT" -path "$ROOT/.git" -prune -o -name '*.fish' -print)
  [ "$n" -gt 0 ] && [ "$bad" = 0 ] && pass "all $n fish files pass fish --no-execute" || fail "all fish files pass fish --no-execute" "bad=$bad"
else
  echo "  skip  fish is not installed"
fi

echo "== git pack: settings"
if [ "$HAVE_GIT" = 1 ]; then
  cfg="$(git config -f "$ROOT/git/gitconfig" --list)"
  for kv in init.defaultbranch=main push.autosetupremote=true fetch.prune=true rerere.enabled=true merge.conflictstyle=zdiff3 \
            diff.algorithm=histogram diff.colormoved=default branch.sort=-committerdate column.ui=auto tag.sort=version:refname \
            rebase.autosquash=true rebase.updaterefs=true commit.verbose=true; do
    has "$cfg" "^$kv\$" && pass "gitconfig sets $kv" || fail "gitconfig sets $kv"
  done
  has "$cfg" '^pull\.' && fail "the pack must not change how pull works" || pass "the pack does not touch how pull works"
else
  echo "  skip  git is not installed"
fi

echo "== git pack: abbreviations"
if [ "$HAVE_FISH" = 1 ]; then
  for p in git docker; do
    out="$(fish --no-config -i -c "source '$ROOT/$p/fish.fish'; abbr --show" 2>&1)"
    if [ -n "$out" ] && ! has "$out" "error|Error"; then pass "$p snippet loads and defines abbreviations"; else fail "$p snippet loads and defines abbreviations" "$out"; fi
  done
  out="$(fish --no-config -i -c "source '$ROOT/git/fish.fish'; abbr --show" 2>&1)"
  for a in g gst ga gd gds gsw gb gc gcm gp gpl gl gla gundo gcam; do has "$out" "^abbr -a (--set-cursor='%' )?-- $a " && pass "git pack defines the abbreviation $a" || fail "git pack defines the abbreviation $a" "$out"; done
else
  echo "  skip  fish is not installed"
fi

echo "== git pack: gtag (the --tag part)"
if [ "$HAVE_FISH" = 1 ] && [ "$HAVE_GIT" = 1 ]; then
  new_home
  GT="$T/gtag-repo"; mkdir -p "$GT"
  gtg() { GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t fish --no-config -c 'source $argv[1]; cd $argv[2]; eval $argv[3]' "$ROOT/git/extras/tag/functions/gtag.fish" "$GT" "$1" 2>&1; }
  ( cd "$GT" && git init -q -b main . && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m one \
      && for t in v1.2.0 v1.4.2 v1.10.0 v1.12.0-rc1 nightly; do git tag $t; done ) >/dev/null 2>&1
  has "$(gtg gtag)" '^v1.10.0' && pass "gtag: lists the newest version first, 1.10 after 1.9" || fail "gtag: lists the newest version first" "$(gtg gtag)"
  gtg 'gtag patch -y' >/dev/null; check "gtag patch: v1.10.0 -> v1.10.1 (rc and other names ignored)" git -C "$GT" rev-parse -q --verify refs/tags/v1.10.1
  check "gtag makes an annotated tag" bash -c "[ \"\$(git -C '$GT' cat-file -t v1.10.1)\" = tag ]"
  gtg 'gtag minor -y' >/dev/null; check "gtag minor: v1.10.1 -> v1.11.0" git -C "$GT" rev-parse -q --verify refs/tags/v1.11.0
  gtg 'gtag major -y -m "big one"' >/dev/null; check "gtag major: v1.11.0 -> v2.0.0" git -C "$GT" rev-parse -q --verify refs/tags/v2.0.0
  check "gtag -m sets the message" bash -c "git -C '$GT' tag -n1 v2.0.0 | grep -q 'big one'"
  out="$(gtg 'echo n | gtag patch')"; has "$out" "nothing created" && ! git -C "$GT" rev-parse -q --verify refs/tags/v2.0.1 >/dev/null && pass "gtag: answering no creates nothing" || fail "gtag: answering no creates nothing" "$out"
  out="$(gtg 'echo y | gtag patch')"; check "gtag: answering y creates the tag" git -C "$GT" rev-parse -q --verify refs/tags/v2.0.1
  out="$(gtg 'gtag sideways; echo rc=$status')"; has "$out" "rc=2" && pass "gtag rejects an unknown word" || fail "gtag rejects an unknown word" "$out"
  mkdir -p "$T/gtag-plain" && ( cd "$T/gtag-plain" && git init -q -b main . && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m one && git tag 1.0.0 ) >/dev/null 2>&1
  GT="$T/gtag-plain"; gtg 'gtag minor -y' >/dev/null; check "gtag keeps a repository's no-prefix style (1.0.0 -> 1.1.0)" git -C "$GT" rev-parse -q --verify refs/tags/1.1.0
  mkdir -p "$T/gtag-empty" && ( cd "$T/gtag-empty" && git init -q -b main . && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m one ) >/dev/null 2>&1
  GT="$T/gtag-empty"; gtg 'gtag patch -y' >/dev/null; check "gtag: the first tag in a repository without versions is v0.0.1" git -C "$GT" rev-parse -q --verify refs/tags/v0.0.1
  mkdir -p "$T/gtag-nogit"; GT="$T/gtag-nogit"; out="$(gtg 'gtag patch -y; echo rc=$status')"; has "$out" "not inside a git repository" && has "$out" "rc=1" && pass "gtag outside a repository says so" || fail "gtag outside a repository says so" "$out"
  out="$(fish --no-config -c 'source $argv[1]; source $argv[2]; complete -C "gtag "' "$ROOT/git/extras/tag/functions/gtag.fish" "$ROOT/git/extras/tag/completions/gtag.fish" 2>&1)"
  has "$out" "^major" && has "$out" "^patch" && pass "gtag tab completion offers major/minor/patch" || fail "gtag tab completion" "$out"
else
  echo "  skip  fish or git is not installed"
fi

echo "== git pack: gsync"
if [ "$HAVE_FISH" = 1 ] && [ "$HAVE_GIT" = 1 ]; then
  new_home
  GS="$T/gsync"; mkdir -p "$GS"; gq() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@"; }
  ( cd "$GS" && gq init -q --bare origin.git && gq clone -q origin.git a && gq clone -q origin.git b \
    && cd a && echo 1 > f && gq add f && gq commit -qm one && gq push -q -u origin main \
    && cd ../b && gq pull -q && cd ../a && echo 2 >> f && gq commit -qam two && gq push -q && cd ../b ) >/dev/null 2>&1
  gsy() { fish --no-config -c 'source $argv[1]; cd $argv[2]; gsync' "$ROOT/git/functions/gsync.fish" "$1" 2>&1; }
  gsy "$GS/b" >/dev/null; [ "$(git -C "$GS/b" rev-list --count HEAD)" = 2 ] && pass "gsync: fetches and fast-forwards the current branch" || fail "gsync: fetches and fast-forwards the current branch"
  ( cd "$GS/b" && echo local >> f && gq commit -qam local && cd ../a && echo 3 >> f && gq commit -qam three && gq push -q ) >/dev/null 2>&1
  before="$(git -C "$GS/b" rev-parse HEAD)"; out="$(gsy "$GS/b")"
  [ "$(git -C "$GS/b" rev-parse HEAD)" = "$before" ] && pass "gsync: diverged history stops and changes nothing" || fail "gsync: diverged history stops and changes nothing" "$out"
  mkdir -p "$T/gsync-none"; has "$(gsy "$T/gsync-none")" "not inside a git repository" && pass "gsync outside a repository says so" || fail "gsync outside a repository says so"
else
  echo "  skip  fish or git is not installed"
fi

echo "== git pack: the git part of the prompt (worker and format)"
if [ "$HAVE_FISH" = 1 ] && [ "$HAVE_GIT" = 1 ]; then
  new_home
  P="$ROOT/git"
  g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@"; }
  SC="$T/scenario"; mkdir -p "$SC"
  ( cd "$SC" && g init -q --bare -b main origin.git && g clone -q origin.git a 2>/dev/null
    cd a && g checkout -q -b main 2>/dev/null; echo 1 > f1; echo 1 > f2; echo base > c.txt; g add -A; g commit -qm one; g push -q -u origin main 2>/dev/null
    cd "$SC" && g clone -q origin.git b 2>/dev/null
    ( cd a && echo 2 >> f1 && g commit -qam two && g push -q origin main )
    cd b && echo local > f3 && g add f3 && g commit -qm local && g fetch -q && echo s > stashme && g add stashme && g stash -q \
      && echo staged > f4 && g add f4 && echo mod >> f2 && echo u1 > u1 && echo u2 > u2 ) >/dev/null 2>&1
  worker() { # worker NAME -> "branch ahead behind staged modified untracked conflicted stash"
    local out="$SC/out.$1"; rm -f "$out"
    fish --no-config -c 'source $argv[1]; __boosh_git_worker $argv[2] $argv[3] 999999' "$P/functions/__boosh_git_worker.fish" "$SC/b" "$out" </dev/null >/dev/null 2>&1
    sed 1d "$out" 2>/dev/null | tr '\n' ' ' | sed 's/ $//'
  }
  [ "$(worker dirty)" = "main 1 1 1 1 2 0 1" ] && pass "worker: ahead, behind, staged, modified, untracked, stash" || fail "worker: ahead, behind, staged, modified, untracked, stash" "$(worker dirty)"
  ( cd "$SC/b" && g stash drop -q; g reset -q --hard origin/main; g clean -qfd; g checkout -q --detach HEAD ) >/dev/null 2>&1
  has "$(worker detached)" '^@[0-9a-f]{7} 0 0 0 0 0 0 0$' && pass "worker: detached HEAD shows @sha" || fail "worker: detached HEAD shows @sha" "$(worker detached)"
  ( cd "$SC/b" && g checkout -q main && echo B2 > c.txt && g commit -qam B2 && cd ../a && echo A2 > c.txt && g commit -qam A2 && g push -q origin main && cd ../b && g fetch -q && g merge origin/main ) >/dev/null 2>&1
  [ "$(worker conflict)" = "main 1 1 0 0 0 1 0" ] && pass "worker: merge conflict counted" || fail "worker: merge conflict counted" "$(worker conflict)"
  ( cd "$SC/b" && g merge --abort ) >/dev/null 2>&1
  out="$(fish --no-config -c 'source $argv[1]; __boosh_git_worker /tmp $argv[2] 999999' "$P/functions/__boosh_git_worker.fish" "$SC/out.nogit" </dev/null 2>&1; test -f "$SC/out.nogit" && echo WROTE || echo nothing)"
  [ "$out" = nothing ] && pass "worker: a directory that is not a repo writes nothing" || fail "worker: a directory that is not a repo writes nothing"
  fmt() { fish --no-config -c 'source $argv[1]; set -g __boosh_git_data $argv[2..-1]; __boosh_git_format' "$P/functions/__boosh_git_format.fish" "$@" 2>&1 | strip; }
  [ "$(fmt main 2 1 3 4 5 1 2)" = "main ⇡2 ⇣1 +3 !4 ?5 ✖1 *2" ] && pass "format: all counters" || fail "format: all counters" "$(fmt main 2 1 3 4 5 1 2)"
  [ "$(fmt main 0 0 0 0 0 0 0)" = "main" ] && pass "format: zero counters are hidden" || fail "format: zero counters are hidden" "$(fmt main 0 0 0 0 0 0 0)"
else
  echo "  skip  fish or git is not installed"
fi

echo "== tips pack: finding the abbreviation of a whole command"
if [ "$HAVE_FISH" = 1 ]; then
  new_home
  tf() { fish --no-config -c 'source $argv[1]
    abbr -a g git; abbr -a gst "git status -sb"; abbr -a gd "git diff"; abbr -a gds "git diff --staged"
    abbr -a --set-cursor gcm "git commit -m \"%\""; abbr -a --position anywhere L "| less"; abbr -a lg lazygit
    __boosh_tips_find $argv[2]' "$ROOT/tips/functions/__boosh_tips_find.fish" "$1" 2>&1 | tr '\t' '>'; }
  [ "$(tf 'git status -sb')" = "gst>git status -sb" ] && pass "tips: a whole command finds its abbreviation" || fail "tips: a whole command finds its abbreviation" "$(tf 'git status -sb')"
  [ "$(tf 'git status -sb -v')" = "gst>git status -sb" ] && pass "tips: extra arguments after it still match" || fail "tips: extra arguments after it still match"
  [ -z "$(tf 'git status -sbx')" ] && pass "tips: a longer word does not match (-sbx)" || fail "tips: a longer word does not match (-sbx)"
  [ "$(tf 'git diff --staged foo')" = "gds>git diff --staged" ] && pass "tips: the longest expansion wins (gds, not gd or g)" || fail "tips: the longest expansion wins" "$(tf 'git diff --staged foo')"
  [ -z "$(tf 'git push')" ] && pass "tips: nothing is suggested for a command without an abbreviation (g saves only 2 characters)" || fail "tips: g=git must not be suggested" "$(tf 'git push')"
  [ "$(tf 'git commit -m "fix it"')" = "gcm>git commit -m \"%\"" ] && pass "tips: an abbreviation with a cursor marker matches what comes before it" || fail "tips: cursor-marker abbreviation" "$(tf 'git commit -m "fix it"')"
  [ "$(tf 'cd x && git status -sb')" = "gst>git status -sb" ] && [ "$(tf 'echo a | git diff')" = "gd>git diff" ] && pass "tips: commands joined with && ; | are looked at one by one" || fail "tips: joined commands"
  [ "$(tf lazygit)" = "lg>lazygit" ] && pass "tips: a one-word expansion is suggested when it saves enough (lg for lazygit)" || fail "tips: lg for lazygit"
  [ -z "$(tf 'ls | less')" ] && pass "tips: --position anywhere abbreviations are ignored" || fail "tips: --position anywhere abbreviations are ignored"
  [ -z "$(tf '')" ] && pass "tips: an empty line is fine" || fail "tips: an empty line is fine"

  echo "== tips pack: when the tip is shown"
  ti() { # ti MODE LINE... : source the pack, define gst, then run LINE... as if they had just been executed
    local mode="$1"; shift
    fish --no-config -i -c 'source $argv[1]; source $argv[2]; set -g boosh_tips $argv[3]
      abbr -a gst "git status -sb"
      for l in $argv[4..-1]; emit fish_postexec $l; end' "$ROOT/tips/fish.fish" "$ROOT/tips/functions/__boosh_tips_find.fish" "$mode" "$@" 2>&1 | strip | grep -c '^tip: '; }
  [ "$(ti once 'git status -sb' 'git status -sb')" = 1 ] && pass "tips: by default each tip is shown once per session" || fail "tips: once per session" "$(ti once 'git status -sb' 'git status -sb')"
  [ "$(ti every 'git status -sb' 'git status -sb')" = 2 ] && pass "tips: boosh-tips every shows it each time" || fail "tips: every"
  [ "$(ti off 'git status -sb' 'git status -sb')" = 0 ] && pass "tips: off shows nothing" || fail "tips: off"
  [ "$(ti once 'git status')" = 0 ] && pass "tips: a command without a short form gets no tip" || fail "tips: no short form, no tip"
  out="$(fish --no-config -i -c 'source $argv[1]; source $argv[2]; set -g boosh_tips every; abbr -a gst "git status -sb"
      set -g __boosh_tips_used 1; emit fish_postexec "git status -sb"; echo "after-used=$__boosh_tips_used"; emit fish_postexec "git status -sb"' "$ROOT/tips/fish.fish" "$ROOT/tips/functions/__boosh_tips_find.fish" 2>&1 | strip)"
  has "$out" 'after-used=0' && [ "$(grep -c '^tip: ' <<< "$out")" = 1 ] && pass "tips: a line where the abbreviation was used earns no tip, and the next line is judged on its own" || fail "tips: used abbreviation earns no tip" "$out"
  out="$(fish --no-config -i -c 'source $argv[1]; source $argv[2]; source $argv[3]; boosh-tips off; boosh-tips; boosh-tips every; boosh-tips bogus; echo rc=$status' "$ROOT/tips/fish.fish" "$ROOT/tips/functions/boosh-tips.fish" "$ROOT/tips/functions/__boosh_tips_find.fish" 2>&1 | strip)"
  has "$out" 'tips: off' && has "$out" 'tips: every' && has "$out" "unknown 'bogus'" && has "$out" 'rc=2' && pass "boosh-tips: off / every / status, and a wrong word is refused" || fail "boosh-tips command" "$out"
else
  echo "  skip  fish is not installed"
fi

echo "== installing the git pack (needs a boosh checkout)"
if [ -n "$BASE" ] && [ "$HAVE_GIT" = 1 ]; then
  cleanup; new_home
  git config --global user.name test >/dev/null 2>&1 || true
  out="$("$BASE/pack" list)"
  has "$out" "git +available" && has "$out" "docker +available" && pass "pack list shows the catalog" || fail "pack list shows the catalog" "$out"
  out="$("$BASE/pack" show git)"
  has "$out" "gst +=" && pass "pack show lists abbreviations" || fail "pack show lists abbreviations"
  "$BASE/pack" add git --no-tools >/dev/null 2>&1
  check "git pack links the fish snippet" test -L "$HOME/.config/fish/conf.d/pack-git.fish"
  check "git pack links the git config" test -L "$HOME/.config/git/pack-git.conf"
  check "git pack links its fish functions (the prompt's git part, gsync)" bash -c "[ -L '$HOME/.config/fish/functions/__boosh_git_worker.fish' ] && [ -e '$HOME/.config/fish/functions/__boosh_git_format.fish' ] && [ -e '$HOME/.config/fish/functions/__boosh_git_fields.fish' ] && [ -e '$HOME/.config/fish/functions/gsync.fish' ]"
  check "git include.path is set" bash -c "git config --global --get-all include.path | grep -qx '~/.config/git/pack-git.conf'"
  check "git settings take effect" bash -c "[ \"\$(git config --get push.autosetupremote)\" = true ] && [ \"\$(git config --get merge.conflictstyle)\" = zdiff3 ] && [ \"\$(git config --get tag.sort)\" = version:refname ]"
  check "the pack does not touch how pull works" bash -c "! git config --get pull.rebase && ! git config --get pull.ff"
  check "pack status is healthy" "$BASE/pack" status
  # delta only while the command exists
  mkdir -p "$HOME/bin"; printf '#!/bin/sh\ncat\n' > "$HOME/bin/delta"; chmod +x "$HOME/bin/delta"
  PATH="$HOME/bin:$PATH" "$BASE/pack" add git --no-tools >/dev/null 2>&1
  check "delta config is included while delta exists" bash -c "PATH='$HOME/bin:$PATH' git config --get core.pager | grep -qx delta"
  "$BASE/pack" add git --no-tools >/dev/null 2>&1
  check "re-adding switches the delta config off" bash -c "! git config --get core.pager"
  # the optional part
  "$BASE/pack" add git --tag --no-tools >/dev/null 2>&1
  check "--tag links gtag and its completions" bash -c "[ -L '$HOME/.config/fish/functions/gtag.fish' ] && [ -L '$HOME/.config/fish/completions/gtag.fish' ]"
  "$BASE/pack" add git --no-tools >/dev/null 2>&1
  check "a plain re-add keeps gtag" test -L "$HOME/.config/fish/functions/gtag.fish"
  "$BASE/pack" remove git --tag >/dev/null 2>&1
  check "remove --tag removes only gtag" bash -c "[ ! -L '$HOME/.config/fish/functions/gtag.fish' ] && [ -L '$HOME/.config/fish/functions/gsync.fish' ]"
  "$BASE/pack" remove git >/dev/null 2>&1
  check "remove takes every file away again" bash -c "[ -z \"\$(find '$HOME/.config' -type l)\" ] && ! git config --global --get-all include.path | grep -q pack-git"
  # a value the user already set must not be overridden silently
  git config --global push.autoSetupRemote false
  out="$("$BASE/pack" add git --no-tools 2>&1)"
  has "$out" "yours=false" && pass "conflicting git setting is reported" || fail "conflicting git setting is reported"
  check "...and left alone without --yes" bash -c "[ \"\$(git config --get push.autosetupremote)\" = false ]"
  "$BASE/pack" add git --no-tools --yes >/dev/null 2>&1
  check "--yes lets the pack win" bash -c "[ \"\$(git config --get push.autosetupremote)\" = true ]"
  # docker
  "$BASE/pack" add docker --no-tools >/dev/null 2>&1
  check "docker pack links its snippet" test -L "$HOME/.config/fish/conf.d/pack-docker.fish"
else
  echo "  skip  needs a boosh checkout and git"
fi

echo "== the boosh prompt with the git pack (needs a boosh checkout and fish)"
if [ -n "$BASE" ] && [ "$HAVE_FISH" = 1 ] && [ "$HAVE_GIT" = 1 ]; then
  cleanup; new_home
  g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@"; }
  "$BASE/install.sh" --yes --no-cheatsheet --editor none --prompt boosh >/dev/null 2>&1
  fish -c "set -U fish_greeting ''" >/dev/null 2>&1   # no banner in front of the output we compare
  bp() { fish -i -c "$1" 2>&1 | strip | grep -v "Welcome to fish"; }
  out="$(bp 'boosh-prompt --git off; echo rc=$status')"
  has "$out" "git pack" && has "$out" "rc=2" && pass "without the git pack, boosh-prompt --git explains what to do" || fail "without the git pack, boosh-prompt --git explains what to do" "$out"
  "$BASE/pack" add git --no-tools >/dev/null 2>&1
  out="$(fish -i -c 'set -g __boosh_git_data main 2 1 3 4 5 1 2; false; fish_prompt' 2>&1 | strip)"
  has "$out" 'main ⇡2 ⇣1 \+3 !4 \?5 ✖1 \*2' && has "$out" '✘1' && pass "the prompt shows the git part once the pack is installed" || fail "the prompt shows the git part once the pack is installed" "$out"
  bp 'boosh-prompt --reset >/dev/null'
  has "$(bp 'boosh-prompt')" "git +on" && pass "boosh-prompt: the git setting is on with the pack" || fail "boosh-prompt: the git setting is on with the pack" "$(bp 'boosh-prompt')"
  bp 'boosh-prompt --fields modified,branch >/dev/null'
  out="$(bp 'set -g __boosh_git_data main 2 1 3 4 5 1 2; __boosh_git_format')"
  [ "$out" = "!4 main" ] && pass "boosh-prompt --fields: chosen parts, in the given order" || fail "boosh-prompt --fields: chosen parts, in the given order" "$out"
  out="$(cd "$ROOT" && bp 'boosh-prompt --git on >/dev/null; emit fish_prompt; echo "pid=[$__boosh_git_pid]"')"
  has "$out" 'pid=\[[0-9]+\]' && pass "git on: a background job is started" || fail "git on: a background job is started" "$out"
  out="$(cd "$ROOT" && bp 'boosh-prompt --git off >/dev/null; emit fish_prompt; echo "pid=[$__boosh_git_pid]"')"
  has "$out" 'pid=\[\]' && pass "boosh-prompt --git off: no background job at all" || fail "boosh-prompt --git off: no background job at all" "$out"
  bp 'boosh-prompt --git on >/dev/null'
  for bad in "--git maybe" "--fields nope" "--git off --fields branch"; do
    out="$(bp "boosh-prompt $bad; echo exit=\$status")"
    has "$out" 'exit=2' && pass "boosh-prompt rejects $bad" || fail "boosh-prompt rejects $bad" "$out"
  done
  out="$(bp "complete -C 'boosh-prompt --fields '")"
  has "$out" '^branch' && has "$out" '^all' && pass "tab completion for --fields lists the parts of the git pack" || fail "tab completion for --fields lists the parts of the git pack" "$out"
  "$BASE/pack" remove git >/dev/null 2>&1
  out="$(fish -i -c 'true; fish_prompt' 2>&1 | strip)"
  has "$out" '❯' && ! has "$out" 'nknown command|rror' && pass "after removing the pack, the prompt works without the git part" || fail "after removing the pack, the prompt works without the git part" "$out"
  if [ "${BOOSH_TEST_PTY:-0}" = 1 ] && command -v script >/dev/null 2>&1; then
    "$BASE/pack" add git --no-tools >/dev/null 2>&1
    SC="$T/scenario"; mkdir -p "$SC"
    ( cd "$SC" && g init -q --bare -b main origin.git && g clone -q origin.git b 2>/dev/null && cd b && echo 1 > f1 && g add f1 && g commit -qm one && g push -q -u origin main && echo mod >> f1 && echo n > new1 && echo n > new2 ) >/dev/null 2>&1
    out="$( cd "$SC/b" && { sleep 2; printf '\n'; sleep 2; printf 'exit\n'; sleep 0.5; } | LANG=C.UTF-8 script -qec "stty rows 20 cols 90; fish -i" /dev/null 2>/dev/null | tr -d '\r' | strip )"
    has "$out" 'main.*!1.*\?2' && pass "async result repaints the prompt in a live fish" || fail "async result repaints the prompt in a live fish"
  fi
else
  echo "  skip  needs a boosh checkout, fish and git"
fi

echo "== tips pack: installing it, and the real keys (needs a boosh checkout and fish)"
if [ -n "$BASE" ] && [ "$HAVE_FISH" = 1 ]; then
  cleanup; new_home
  "$BASE/pack" add tips >/dev/null 2>&1
  check "tips links its snippet, commands and completions" bash -c "[ -L '$HOME/.config/fish/conf.d/pack-tips.fish' ] && [ -L '$HOME/.config/fish/functions/boosh-tips.fish' ] && [ -L '$HOME/.config/fish/functions/__boosh_tips_find.fish' ] && [ -L '$HOME/.config/fish/completions/boosh-tips.fish' ]"
  check "pack status is healthy with it" "$BASE/pack" status
  out="$(fish -i -c 'boosh-tips' 2>&1 | strip)"; has "$out" 'tips: on' && pass "boosh-tips works in a fresh fish" || fail "boosh-tips works in a fresh fish" "$out"
  if [ "${BOOSH_TEST_PTY:-0}" = 1 ] && command -v script >/dev/null 2>&1; then
    mkdir -p "$T/repo" && ( cd "$T/repo" && git init -q . ) >/dev/null 2>&1
    fish -c "set -U fish_greeting ''" >/dev/null 2>&1
    # typed through a real terminal: gst, the full command, the full command again, then "every" and the full command twice
    out="$( cd "$T/repo" && { sleep 1.5; printf "abbr -a gst 'git status -sb'\r"; sleep 0.6; printf 'gst\r'; sleep 0.8; printf 'git status -sb\r'; sleep 0.8; printf 'git status -sb\r'; sleep 0.8; printf 'boosh-tips every\r'; sleep 0.6; printf 'git status -sb\r'; sleep 0.8; printf 'git status -sb\r'; sleep 0.8; printf 'exit\r'; sleep 0.4; } | LANG=C.UTF-8 script -qec "stty rows 40 cols 100; fish -i" /dev/null 2>/dev/null | tr -d '\r' | strip )"
    n="$(grep -c '^tip: you can type gst instead of git status -sb' <<< "$out")"
    [ "$n" = 3 ] && pass "real keys: no tip for gst, one for the full command (once per session), then one per line with boosh-tips every" || fail "real keys: tips" "tips shown=$n (expected 3)"
  fi
else
  echo "  skip  needs a boosh checkout and fish"
fi

echo
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
