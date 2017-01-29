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
    if [[ $SRCDEST ]]; then
        [[ $count -eq 1 ]] && printf "\n%s\n %s\n" $"Sources to keep:" $"All development packages sources"
        printf "\n%s %s\n" $"AUR source cache directory:" "$SRCDEST"
        if [[ $count -eq 1 ]]; then
            if Proceed "y" $"Do you want to remove all non development files from AUR source cache?"; then
                printf "%s\n" $"removing non development files from source cache..."
                rm -f $SRCDEST/* &>/dev/null
            fi
        else
            if ! Proceed "n" $"Do you want to remove ALL files from AUR source cache?"; then
                printf "%s\n" $"removing all files from AUR source cache..."
                rm -rf $SRCDEST/* &>/dev/null
            fi
        fi
    fi
    if [[ -d "$clonedir" ]]; then
        cd $clonedir
        [[ $count -eq 1 ]] && printf "\n%s\n %s\n" $"Clones to keep:" $"All packages clones"
        printf "\n%s %s\n" $"AUR clone directory:" "$clonedir"
        if [[ $count -eq 1 ]]; then
            if Proceed "y" $"Do you want to remove all uninstalled clones from AUR clone directory?"; then
                foreignpkgsbase=($(expac -Q '%n %e' $($pacmanbin -Qmq) | awk '{if ($2 == "(null)") print $1; else print $2}'))
                printf "%s\n\n" $"removing uninstalled clones from AUR clone cache..."
                for clone in *; do
                    [[ -d "$clonedir/$clone" && ! " ${foreignpkgsbase[@]} " =~ " $clone " ]] && rm -rf "$clonedir/$clone"
                done
            fi
            if Proceed "y" $"Do you want to remove all untracked files from AUR clone directory?"; then
                printf "%s\n" $"removing untracked files from AUR clone cache..."
                for clone in *; do
                    [[ -d "$clonedir/$clone" ]] && git --git-dir="$clone/.git" --work-tree="$clone" clean -ffdx &>/dev/null
                done
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
