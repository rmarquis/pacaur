#!/bin/bash
#
#   cache.sh - functions related to cache management
#

##
# Clean AUR cache, including sources and clone directories. This function let
# users select what content is deleted.
#
# usage: CleanCache( $packages )
##
CleanCache() {
    cachedir=($(grep '^CacheDir' '/etc/pacman.conf' | cut -d '=' -f2 | cut -d '#' -f1))
    [[ $cachedir ]] && cachedir=${cachedir[@]%/} && PKGDEST=${PKGDEST%/}

    if [[ $PKGDEST && ! " ${cachedir[@]} " =~ " $PKGDEST " ]]; then
        [[ $count -eq 1 ]] && printf "\n%s\n %s\n" $"Packages to keep:" $"All locally installed packages"
        printf "\n%s %s\n" $"AUR cache directory:" "$PKGDEST"
        if [[ $count -eq 1 ]]; then
            if Proceed "y" $"Do you want to remove all other packages from AUR cache?"; then
                printf "%s\n" $"removing old packages from cache..."
                for i in $(ls $PKGDEST | sed "s#\(.*\)-.*#\1#g" ); do
                    pkgname=$(sed "s#\(.*\)-.*-.*#\1#g" <<< $i)
                    [[ $i != $(expac -Q '%n-%v' "$pkgname") ]] && rm "$PKGDEST"/$i-*
                done
            fi
        else
            if ! Proceed "n" $"Do you want to remove ALL files from AUR cache?"; then
                printf "%s\n" $"removing all files from AUR cache..."
                rm "$PKGDEST"/* &>/dev/null
            fi
        fi
    fi
    # clean AUR sources cache
    if [[ $SRCDEST ]]; then
        [[ $count -eq 1 ]] && printf "\n%s\n %s\n" $"Sources to keep:" $"All development packages sources"
        printf "\n%s %s\n" $"AUR source cache directory:" "$SRCDEST"
        if [[ $count -eq 1 ]]; then
            if Proceed "y" $"Do you want to remove all non development files from AUR source cache?"; then
                printf "%s\n" $"removing non development files from source cache..."
                rm -f "$SRCDEST"/* &>/dev/null
            fi
        else
            if ! Proceed "n" $"Do you want to remove ALL files from AUR source cache?"; then
                printf "%s\n" $"removing all files from AUR source cache..."
                rm -rf "$SRCDEST"/* &>/dev/null
            fi
        fi
    fi
    # clean clone directory cache
    if [[ -d "$clonedir" ]]; then
        cd $clonedir
        if [[ $count -eq 1 ]]; then
            if [[ -z "${pkgs[@]}" ]]; then
                printf "\n%s\n %s\n" $"Clones to keep:" $"All locally installed clones"
            else
                printf "\n%s\n %s\n" $"Clones to keep:" $"All other locally installed clones"
            fi
        fi
        printf "\n%s %s\n" $"AUR clone directory:" "$clonedir"
        if [[ $count -eq 1 ]]; then
            foreignpkgsbase=($(expac -Q '%n %e' $($pacmanbin -Qmq) | awk '{if ($2 == "(null)") print $1; else print $2}'))
            # get target
            if [[ -n "${pkgs[@]}" ]]; then
                pkgsbase=($(expac -Q %e ${pkgs[@]}))
                aurpkgsbase=($(grep -xf <(printf '%s\n' "${pkgsbase[@]}") <(printf '%s\n' "${foreignpkgsbase[@]}")))
                if Proceed "y" $"Do you want to remove ${aurpkgsbase[*]} clones from AUR clone directory?"; then
                    printf "%s\n\n" $"removing uninstalled clones from AUR clone cache..."
                    for clone in "${aurpkgsbase[@]}"; do
                        [[ -d "$clonedir/$clone" ]] && rm -rf "$clonedir/$clone"
                    done
                fi
            else
                if Proceed "y" $"Do you want to remove all uninstalled clones from AUR clone directory?"; then
                    printf "%s\n\n" $"removing uninstalled clones from AUR clone cache..."
                    for clone in *; do
                        [[ -d "$clonedir/$clone" && ! " ${foreignpkgsbase[@]} " =~ " $clone " ]] && rm -rf "$clonedir/$clone"
                    done
                fi
                #if [[ ! $PKGDEST || ! $SRCDEST ]]; then # pacman 5.1
                    if Proceed "y" $"Do you want to remove all untracked files from AUR clone directory?"; then
                        printf "%s\n" $"removing untracked files from AUR clone cache..."
                        for clone in *; do
                            [[ -d "$clonedir/$clone" ]] && git --git-dir="$clone/.git" --work-tree="$clone" clean -ffdx &>/dev/null
                        done
                    fi
                #fi
            fi
        else
            if ! Proceed "n" $"Do you want to remove ALL clones from AUR clone directory?"; then
                printf "%s\n" $"removing all clones from AUR clone cache..."
                for clone in *; do
                    [[ -d "$clonedir/$clone" ]] && rm -rf "$clonedir/$clone"
                done
            fi
        fi
    fi
    exit 0
}
# vim:set ts=4 sw=2 et:
