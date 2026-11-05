# Runs in a background fish. ONE git call gives branch, ahead, behind, staged, modified, untracked, conflicted;
# one more gives the stash count. Result goes to a file, then the parent gets SIGUSR1.
function __boosh_git_worker --argument-names root out ppid
    set -x GIT_OPTIONAL_LOCKS 0   # never take the index lock: do not disturb the user's own git commands
    set -l data (command git -C $root status --porcelain=v2 --branch --untracked-files=normal 2>/dev/null | awk '
        /^# branch.oid/  { oid = $3 }
        /^# branch.head/ { b = $3 }
        /^# branch.ab/   { a = substr($3, 2); d = substr($4, 2) }
        /^[12] /         { if (substr($2, 1, 1) != ".") s++; if (substr($2, 2, 1) != ".") m++ }
        /^u /            { c++ }
        /^\? /           { u++ }
        END {
            if (b == "(detached)") b = "@" substr(oid, 1, 7)
            print b; print a + 0; print d + 0; print s + 0; print m + 0; print u + 0; print c + 0
        }')
    test (count $data) -ge 7; and test -n "$data[1]"; or return   # not a repository, or git failed: write nothing
    set -l stash (command git -C $root rev-list --walk-reflogs --count refs/stash 2>/dev/null; or echo 0)
    printf '%s\n' $root $data $stash >$out.tmp
    mv -f $out.tmp $out
    kill -USR1 $ppid 2>/dev/null
end
