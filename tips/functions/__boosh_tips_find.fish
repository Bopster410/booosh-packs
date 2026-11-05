# __boosh_tips_find COMMANDLINE : prints "ABBREVIATION<TAB>EXPANSION" for the best abbreviation the command line spells out
# in full, and fails when there is none. Only abbreviations that save at least $boosh_tips_min characters (default 4)
# count, so "git" is never suggested as "g". Of several matches the longest expansion wins (gst, not g).
# Several commands in one line (a && b; c | d) are looked at one by one. Abbreviations that are not plain text
# (--position anywhere, --regex, --function) are skipped.
function __boosh_tips_find
    set -l min 4
    set -q boosh_tips_min; and set min $boosh_tips_min
    set -l segs (string replace -ra -- '\s*(&&|\|\||;|\|)\s*' \n "$argv[1]" | string split -n \n)
    test (count $segs) -gt 0; or return 1
    set -l best_name
    set -l best_exp
    set -l best_len 0
    for def in (abbr --show)
        set -l m (string match -r -- '^abbr -a (.*?)-- (\S+) (.*)$' $def); or continue
        string match -q -- '*--position*' "$m[2]"; and continue
        string match -q -- '*--regex*' "$m[2]"; and continue
        string match -q -- '*--function*' "$m[2]"; and continue
        set -l name $m[3]
        set -l exp (string unescape -- $m[4])
        set -l prefix $exp
        string match -q -- '*%*' "$exp"; and set prefix (string replace -r -- '%.*$' '' "$exp")   # --set-cursor: what comes before the cursor
        set -l plen (string length -- "$prefix")
        test $plen -gt 0; or continue
        test (math (string length -- "$exp") - (string length -- "$name")) -ge $min; or continue
        test $plen -gt $best_len; or continue
        for seg in $segs
            test (string sub -l $plen -- "$seg") = "$prefix"; or continue
            # the expansion must end where a word ends: "git status -sb" matches "git status -sb -v", not "git status -sbx"
            set -l next (string sub -s (math $plen + 1) -l 1 -- "$seg")
            if test -n "$next"; and string match -qr '\w' -- $next; and string match -qr '\w$' -- "$prefix"
                continue
            end
            set best_name $name
            set best_exp $exp
            set best_len $plen
            break
        end
    end
    test -n "$best_name"; or return 1
    printf '%s\t%s\n' $best_name $best_exp
end
