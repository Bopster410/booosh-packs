# pack: tips (managed by boosh/pack; edit it in the repo, not here)
# When you type a whole command that has an abbreviation (git status -sb, while gst exists), a gray line under its
# output tells you the short form. Not when you used the abbreviation, and by default only once per session for each.
#   boosh-tips                 show the mode          boosh-tips on|every|off     once per session / every time / never
#
# fish saves the EXPANDED text in its history, so "typed it in full" cannot be read from the command alone. Space and
# Enter are bound here only to notice that an abbreviation was just expanded; they otherwise do what they always did.
if status is-interactive
    set -g __boosh_tips_used 0

    function __boosh_tips_note   # an abbreviation under the cursor is about to be expanded: that line earns no tip
        set -l tok (commandline -t)
        test -n "$tok"; and abbr --query -- $tok; and set -g __boosh_tips_used 1
    end

    function __boosh_tips_space
        __boosh_tips_note
        commandline -f expand-abbr
        commandline -i ' '
    end

    function __boosh_tips_enter
        __boosh_tips_note
        commandline -f execute
    end

    function __boosh_tips_bind --on-variable fish_key_bindings   # fish resets the bindings when you change the key style
        for mode in default insert
            bind -M $mode space __boosh_tips_space
            bind -M $mode enter __boosh_tips_enter
        end
    end
    __boosh_tips_bind

    function __boosh_tips_postexec --on-event fish_postexec
        set -l used $__boosh_tips_used
        set -g __boosh_tips_used 0
        test "$used" = 1; and return
        set -l mode once
        set -q boosh_tips; and set mode $boosh_tips
        test "$mode" = off; and return
        set -l hit (__boosh_tips_find "$argv[1]"); or return
        set -l parts (string split \t -- $hit)
        if test "$mode" != every
            contains -- $parts[1] $__boosh_tips_seen; and return
            set -ga __boosh_tips_seen $parts[1]
        end
        set_color brblack
        echo "tip: you can type $parts[1] instead of "(string replace -a -- % … $parts[2])
        set_color normal
    end
end
