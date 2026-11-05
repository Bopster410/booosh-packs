# boosh-tips: tips about abbreviations (the tips pack)
function boosh-tips --description 'Show or change the abbreviation tips: on, every, off'
    set -l mode once
    set -q boosh_tips; and set mode $boosh_tips
    switch "$argv[1]"
        case '' status
            switch $mode
                case once;  echo "tips: on (each tip once per session)"
                case every; echo "tips: every (the tip every time you type the long form)"
                case off;   echo "tips: off"
            end
            echo "(boosh-tips on | every | off)"
        case on once
            set -U boosh_tips once; echo "tips: on (each tip once per session)"
        case every
            set -U boosh_tips every; echo "tips: every"
        case off
            set -U boosh_tips off; echo "tips: off"
        case reset
            set -e __boosh_tips_seen; echo "tips: this session will show each tip again"
        case -h --help
            echo 'boosh-tips [status] | on | every | off | reset'
        case '*'
            echo "boosh-tips: unknown '$argv[1]' (on, every, off, reset, status)" >&2
            return 2
    end
end
