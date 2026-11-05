# pack: docker (managed by boosh/pack; edit it in the repo, not here)
# Defined only when docker exists. The compose abbreviations pick "docker compose"
# or the old "docker-compose" at expansion time, so shell startup stays fast.
if status is-interactive; and type -q docker
    function __pack_docker_dc
        if not set -q __pack_docker_dc_cmd
            if docker compose version >/dev/null 2>&1
                set -g __pack_docker_dc_cmd docker compose
            else if type -q docker-compose
                set -g __pack_docker_dc_cmd docker-compose
            else
                set -g __pack_docker_dc_cmd docker compose
            end
        end
        string join ' ' -- $__pack_docker_dc_cmd $argv
    end
    function __pack_docker_dcup; __pack_docker_dc up -d; end
    function __pack_docker_dcdn; __pack_docker_dc down; end
    function __pack_docker_dcl; __pack_docker_dc logs -f; end
    function __pack_docker_dcps; __pack_docker_dc ps; end
    function __pack_docker_dcb; __pack_docker_dc build; end

    abbr -a d docker
    abbr -a dps 'docker ps'
    abbr -a dpsa 'docker ps -a'
    abbr -a di 'docker images'
    abbr -a dlogs 'docker logs -f'
    abbr -a dex --set-cursor 'docker exec -it % sh'
    abbr -a dcup --function __pack_docker_dcup
    abbr -a dcdn --function __pack_docker_dcdn
    abbr -a dcl --function __pack_docker_dcl
    abbr -a dcps --function __pack_docker_dcps
    abbr -a dcb --function __pack_docker_dcb

    if type -q lazydocker
        abbr -a lzd lazydocker
    end
end
