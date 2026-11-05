# pack: git (managed by boosh/pack; edit it in the repo, not here)
# Needs fish >= 3.6 (abbr --set-cursor). Defined in conf.d, so abbreviations
# you set later in config.fish win over these.
if status is-interactive
    abbr -a g git
    abbr -a gst 'git status -sb'
    abbr -a ga 'git add'
    abbr -a gd 'git diff'
    abbr -a gds 'git diff --staged'
    abbr -a gsw 'git switch'
    abbr -a gb 'git branch'
    abbr -a gc 'git commit'
    abbr -a gcm --set-cursor 'git commit -m "%"'
    abbr -a gp 'git push'
    abbr -a gpl 'git pull'
    abbr -a gl 'git log --oneline --graph --decorate -20'
    abbr -a gla 'git log --oneline --graph --decorate --all -20'
    abbr -a gundo 'git reset --soft HEAD~1'
    abbr -a gcam --set-cursor 'git commit -am "%"'

    if type -q lazygit
        abbr -a lg lazygit
    end

    # git info for fish's OWN prompt (fish_git_prompt ships with fish). The boosh prompt does not use these.
    set -g __fish_git_prompt_showdirtystate yes
    set -g __fish_git_prompt_showuntrackedfiles yes
    set -g __fish_git_prompt_showupstream auto
    set -g __fish_git_prompt_showcolorhints yes

    # ---- git info in the boosh prompt (the prompt itself lives in the core and shows it only if this pack is installed)
    # git status is computed in a background fish, the result arrives by a signal, then the prompt is repainted.
    # Technique as in Hydro by Jorge Bucaran (MIT); this is a separate, much smaller implementation.
    # Files: functions/__boosh_git_worker.fish (the job), __boosh_git_format.fish (the look), __boosh_git_fields.fish (the parts).
    set -g __boosh_git_data
    set -g __boosh_git_root
    set -g __boosh_git_pid
    set -g __boosh_git_out (set -q XDG_RUNTIME_DIR; and echo $XDG_RUNTIME_DIR; or echo /tmp)/boosh-git-$fish_pid

    # repo root without starting a process: walk up looking for .git
    function __boosh_git_find_root
        set -l d $PWD
        while test "$d" != /
            test -e $d/.git; and echo $d; and return
            set d (path dirname $d)
        end
    end

    # right before each prompt: start the background job and do not wait for it
    function __boosh_git_kick --on-event fish_prompt
        # not the boosh prompt (fish's own prompt, another plugin): nobody would show the result
        set -q __boosh_prompt_active; or return
        # git switched off (boosh-prompt --git off): no job at all
        if set -q boosh_prompt_git_fields; and test (count $boosh_prompt_git_fields) -eq 0
            set -g __boosh_git_data
            set -g __boosh_git_root
            return
        end
        set -l root (__boosh_git_find_root)
        if test -z "$root"
            set -g __boosh_git_data
            set -g __boosh_git_root
            return
        end
        if test "$root" != "$__boosh_git_root"   # another repository: never show the old one's data
            set -g __boosh_git_data
            set -g __boosh_git_root $root
        end
        # an older job is still running (huge repo, quick Enter): stop it, but only if that pid is really ours
        if test -n "$__boosh_git_pid"
            ps -p $__boosh_git_pid -o args= 2>/dev/null | string match -q '*__boosh_git_worker*'
            and command kill $__boosh_git_pid 2>/dev/null
        end
        set -l worker (functions --details __boosh_git_worker)
        test -f "$worker"; or return   # the file is gone (pack removed, repository moved): stay quiet, show no git info
        fish --no-config -c 'source $argv[1]; __boosh_git_worker $argv[2] $argv[3] $argv[4]' $worker $root $__boosh_git_out $fish_pid &
        set -g __boosh_git_pid $last_pid
        disown
    end

    # the job is done: read its result and repaint the prompt
    function __boosh_git_on_result --on-signal USR1
        set -g __boosh_git_pid
        test -f $__boosh_git_out; or return
        set -l l
        while read -l line
            set -a l $line
        end <$__boosh_git_out
        if test "$l[1]" = "$__boosh_git_root"
            set -g __boosh_git_data $l[2..-1]
            commandline -f repaint
        end
    end

    function __boosh_git_cleanup --on-event fish_exit
        rm -f $__boosh_git_out $__boosh_git_out.tmp
    end
end
