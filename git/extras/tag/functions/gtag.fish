# gtag: create the next semantic-version tag.
#   gtag                 the latest version tags
#   gtag patch|minor|major   v1.4.2 -> v1.4.3 | v1.5.0 | v2.0.0 (a "v" prefix is kept as it is)
# Only plain versions (1.2.3 or v1.2.3) count; v1.2.3-rc1 and other names are ignored.
# It makes an annotated tag at HEAD after asking; it never pushes (it prints the command).
function gtag --description 'Create the next semver tag: gtag patch|minor|major'
    argparse -n gtag h/help y/yes 'm/message=' -- $argv; or return 2
    if set -q _flag_help
        echo 'gtag: create the next semantic-version tag
  gtag                      list the latest version tags
  gtag patch|minor|major    v1.4.2 -> v1.4.3 | v1.5.0 | v2.0.0 (the "v" prefix is kept)
  -y, --yes                 do not ask
  -m, --message TEXT        tag message (default: the tag name)
It tags HEAD, never pushes (it prints: git push origin TAG), and only counts tags like 1.2.3 or v1.2.3.'
        return 0
    end
    command git rev-parse --is-inside-work-tree >/dev/null 2>&1; or begin
        echo "gtag: not inside a git repository" >&2
        return 1
    end
    set -l tags (command git tag --list --sort=-v:refname | string match -r '^v?[0-9]+\.[0-9]+\.[0-9]+$')

    if test (count $argv) -eq 0
        if test (count $tags) -eq 0
            echo "no version tags yet (gtag major|minor|patch creates the first one)"
        else
            printf '%s\n' $tags[1..5]
        end
        return 0
    end
    contains -- $argv[1] major minor patch; or begin
        echo "gtag: expected major, minor or patch (got '$argv[1]')" >&2
        return 2
    end

    set -l prefix v
    set -l ver 0 0 0
    if test (count $tags) -gt 0
        set prefix (string replace -r '^(v?).*' '$1' -- $tags[1])
        set ver (string split . (string replace -r '^v' '' -- $tags[1]))
    end
    switch $argv[1]
        case major
            set ver (math $ver[1] + 1) 0 0
        case minor
            set ver $ver[1] (math $ver[2] + 1) 0
        case patch
            set ver $ver[1] $ver[2] (math $ver[3] + 1)
    end
    set -l next $prefix(string join . $ver)

    if command git rev-parse -q --verify "refs/tags/$next" >/dev/null
        echo "gtag: $next already exists" >&2
        return 1
    end
    set -l at (command git log -1 --format='%h %s' HEAD 2>/dev/null); or begin
        echo "gtag: this repository has no commits yet" >&2
        return 1
    end
    set -l from (test (count $tags) -gt 0; and echo $tags[1]; or echo "no version tag yet")
    echo "latest: $from"
    echo "next:   $next  at  $at"
    if not set -q _flag_yes
        read -l -P "create the tag $next? [y/N] " answer; or return 1
        contains -- (string lower -- $answer) y yes; or begin
            echo "nothing created"
            return 1
        end
    end
    set -l msg $next
    set -q _flag_message; and set msg $_flag_message
    command git tag -a $next -m $msg; or return
    echo "created $next. Publish it with: git push origin $next"
end
