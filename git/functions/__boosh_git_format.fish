# How the git info looks. Data (in $__boosh_git_data): branch ahead behind staged modified untracked conflicted stash
# Which parts are shown, and in which order, is the list $boosh_prompt_git_fields (see `boosh-prompt --fields`).
# Edit this function to change symbols or colours.
function __boosh_git_format
    set -l d $__boosh_git_data
    test (count $d) -ge 8; or return
    set -l fields branch ahead behind staged modified untracked conflicts stash
    set -q boosh_prompt_git_fields; and set fields $boosh_prompt_git_fields
    set -l out
    for f in $fields
        switch $f
            case branch;    set -a out (set_color green)$d[1]
            case ahead;     test $d[2] -gt 0; and set -a out (set_color cyan)"⇡$d[2]"        # commits to push
            case behind;    test $d[3] -gt 0; and set -a out (set_color cyan)"⇣$d[3]"        # commits to pull
            case staged;    test $d[4] -gt 0; and set -a out (set_color green)"+$d[4]"       # staged files
            case modified;  test $d[5] -gt 0; and set -a out (set_color yellow)"!$d[5]"      # modified files
            case untracked; test $d[6] -gt 0; and set -a out (set_color blue)"?$d[6]"        # untracked files
            case conflicts; test $d[7] -gt 0; and set -a out (set_color red)"✖$d[7]"         # merge conflicts
            case stash;     test $d[8] -gt 0; and set -a out (set_color magenta)"*$d[8]"     # stashes
        end
    end
    test (count $out) -gt 0; or return
    echo -n (string join ' ' -- $out)   # no newline: the caller embeds this in the prompt line
    set_color normal
end
