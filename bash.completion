#!/bin/bash

#
# /usr/share/bash-completion/completions/pacaur
#

_aur_pkg() {
    # at least 2 characters required due to AUR limitation
    COMPREPLY+=($(compgen -W "$(cower -sq -- ^$cur 2>/dev/null)" -- $cur))
}

_pacaur() {
    # define variables
    local cur op o
    COMPREPLY=()
    cur=$(_get_cword)
    if ((COMP_CWORD == 1)); then
        if [[ $cur != -* ]]; then
            _arch_compgen "${COMPREPLY[@]}" "sync search info buildonly upgrade check clean cleanall"
            _pacman_file
            return 0
        else
            _pacman &> /dev/null
            _arch_compgen "${COMPREPLY[@]}" "-v --version -h --help"
            return 0
        fi
    fi
    for o in 'D database' 'F files' 'Q query' 'R remove' 'S sync' 'T deptest' 'U upgrade' 'V version'; do
        _arch_incomp "$o" && break
    done
    (($?)) && op="" || op="${o% *}"
    _pacman &> /dev/null
    if [[ "$cur" == -* ]]; then
        case "$op" in
            S) _arch_compgen "${COMPREPLY[@]}" "-a --aur -r --repo -e --edit --devel --domain --foreign --noedit --rebuild --silent";;
        esac
    else
        case "$op" in
            S) _pacman_pkg Slq; _aur_pkg;; # No fallback var support.
            info|buildonly|sync) _aur_pkg;;
            upgrade|check) _pacman_pkg Qqm;;
        esac
    fi
}

_completion_loader pacman
complete -o default -F _pacaur pacaur

# vim:set ts=4 sw=2 et:
