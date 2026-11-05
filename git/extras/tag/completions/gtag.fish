complete -c gtag -f
complete -c gtag -n __fish_use_subcommand -a major -d 'v1.4.2 -> v2.0.0'
complete -c gtag -n __fish_use_subcommand -a minor -d 'v1.4.2 -> v1.5.0'
complete -c gtag -n __fish_use_subcommand -a patch -d 'v1.4.2 -> v1.4.3'
complete -c gtag -s y -l yes -d 'Do not ask'
complete -c gtag -s m -l message -x -d 'Tag message'
complete -c gtag -s h -l help -d 'Show help'
