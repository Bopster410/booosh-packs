# The parts of the git info, in their default order. `boosh-prompt --fields` and its completion read this list.
function __boosh_git_fields
    printf '%s\n' branch ahead behind staged modified untracked conflicts stash
end
