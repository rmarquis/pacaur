Proceed() {
    local Y y N n answer
    Y="$(gettext pacman Y)"; y="${Y,,}";
    N="$(gettext pacman N)"; n="${N,,}"
    case "$1" in
        y)  printf "${colorB}%s${reset} ${colorW}%s${reset}" "::" $"$2 [Y/n] "
            if [[ ! $noconfirm ]]; then
                case "$TERM" in
                    dumb)
                        read -r answer
                        ;;
                    *)
                        if [[ $cleancache ]]; then
                            read -r answer
                        else
                            read -r -n 1 answer
                            echo
                        fi
                        ;;
                esac
            else
                answer=$Y
                echo
            fi
            case $answer in
                $Y|$y|'') return 0;;
                *) return 1;;
            esac;;
        n)  printf "${colorB}%s${reset} ${colorW}%s${reset}" "::" $"$2 [y/N] "
            if [[ ! $noconfirm ]]; then
                case "$TERM" in
                    dumb)
                        read -r answer
                        ;;
                    *)
                        if [[ $cleancache ]]; then
                            read -r answer
                        else
                            read -r -n 1 answer
                            echo
                        fi
                        ;;
                esac
            else
                answer=$N
                echo
            fi
            case $answer in
                $N|$n|'') return 0;;
                *) return 1;;
            esac;;
    esac
}

Note() {
    case "$1" in
        i) echo -e "${colorB}::${reset} $2";;       # info
        s) echo -e "${colorG}::${reset} $2";;       # success
        w) echo -e "${colorY}::${reset} $2";;       # warn
        f) echo -e "${colorR}::${reset} $2" >&2;;   # fail
        e) echo -e "${colorR}::${reset} $2" >&2;    # error
           exit 1;;
    esac
}

GetLength() {
    local length=0 i
    for i in "$@"; do
        x=${#i}
        [[ $x -gt $length ]] && length=$x
    done
    echo $length
}

NothingToDo() {
    [[ -z "$@" ]] && printf "%s\n" $" there is nothing to do" && exit || return 0
}

SudoV() {
    touch "/run/user/$UID/pacaur.sudov.lck"
    while [[ -e "/run/user/$UID/pacaur.sudov.lck" ]]; do
        sudo $pacmanbin -V > /dev/null
        sleep 2
    done
}

trap Cancel INT
Cancel() {
    echo
    [[ -e "/run/lock/pacaur.build.lck" ]] && sudo rm "/run/lock/pacaur.build.lck"
    [[ -e "/run/user/$UID/pacaur.sudov.lck" ]] && rm "/run/user/$UID/pacaur.sudov.lck"
    exit
}
