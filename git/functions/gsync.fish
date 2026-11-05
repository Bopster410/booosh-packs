# gsync: bring the current branch up to date without surprises.
#   1. git fetch --prune   download what is new and forget remote branches that were deleted (a merged MR)
#   2. git pull --ff-only  move the current branch forward only if that is a plain fast-forward;
#                          if your history and the remote's have diverged it stops and changes nothing
function gsync --description 'git fetch --prune, then git pull --ff-only'
    command git rev-parse --is-inside-work-tree >/dev/null 2>&1; or begin
        echo "gsync: not inside a git repository" >&2
        return 1
    end
    command git fetch --prune; or return
    command git pull --ff-only
end
