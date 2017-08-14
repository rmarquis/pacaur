#!/bin/bash
#
#   utils.sh - utility functions
#

##
# Print the string and ask user to accept or cancel the operation.
#
# usage: Proceed( $default_option, $string )
##
Proceed() {
    local Y y N n answer readline ret
    Y="$(gettext pacman Y)"; y="${Y,,}";
    N="$(gettext pacman N)"; n="${N,,}"
    if [[ "$TERM" = dumb ]] || [[ $cleancache ]]; then
        readline=1
    else
        readline=0
    fi
    case "$1" in
        y)  printf "${colorB}%s${reset} ${colorW}%s${reset}" "::" "$2 [$Y/$n] "
            if [[ $noconfirm ]]; then
                echo
                return 0
            fi
            while true; do
                if [[ $readline ]]; then
                    read -r answer
                else
                    read -s -r -n 1 answer
                fi
                case $answer in
                    $Y|$y|'') ret=0; break;;
                    $N|$n) ret=1; break;;
                    *) [[ $readline ]] && ret=1 && break;;
                esac
            done;;
        n)  printf "${colorB}%s${reset} ${colorW}%s${reset}" "::" "$2 [$y/$N] "
            if [[ $noconfirm ]]; then
                echo
                return 0
            fi
            while true; do
                if [[ $readline ]]; then
                    read -r answer
                else
                    read -s -r -n 1 answer
                fi
                case $answer in
                    $N|$n|'') ret=0; break;;
                    $Y|$y) ret=1; break;;
                    *) [[ $readline ]] && ret=0 && break;;
                esac
            done;;
    esac
    if ! [[ $readline ]]; then
        echo "$answer"
    fi
    return $ret
}

##
# Print the string with the selected format.
# Current options: info (i), success (s), warning (w), fail (f), error (e).
#
# usage: Note( $option, $string )
##
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

##
# Get number of characters of the string.
#
# usage: GetLength( $string, {$string_2, $string_3, ...} )
##
GetLength() {
    local length=0 i
    for i in "$@"; do
        x=${#i}
        [[ $x -gt $length ]] && length=$x
    done
    echo $length
}

##
# Print a message if there is nothing to do and exit the application. Just
# return if there is any argument.
#
# usage: NothingToDo( $arguments )
##
NothingToDo() {
    [[ -z "$@" ]] && printf "%s\n" $" there is nothing to do" && exit || return 0
}

##
# Keep sudo permissions active. This command should be run on the background.
#
# usage: SudoV() &
##
SudoV() {
    touch "$tmpdir/pacaur.sudov.lck"
    while [[ -e "$tmpdir/pacaur.sudov.lck" ]]; do
        sudo $pacmanbin -V > /dev/null
        sleep 2
    done
}
# vim:set ts=4 sw=2 et:
