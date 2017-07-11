#!/bin/bash
#
#   aur.sh - functions related to AUR operations
#

##
# Check which packages need to be updated.
#
# usage: CheckUpdates( $packages )
##
CheckUpdates() {
    local foreignpkgs foreignpkgsbase repopkgsQood repopkgsQver repopkgsSver repopkgsSrepo repopkgsQgrp repopkgsQignore
    local aurpkgsQood aurpkgsAname aurpkgsAver aurpkgsQver aurpkgsQignore i json
    local aurdevelpkgsAver aurdevelpkgsQver aurpkgsQoodAver lname lQver lSver lrepo lgrp lAname lAQver lASver lArepo

    GetIgnoredPkgs

    if [[ ! "${opts[@]}" =~ "n" && ! " ${pacopts[@]} " =~ --native && $fallback = true ]]; then
        [[ -z "${pkgs[@]}" ]] && foreignpkgs=($($pacmanbin -Qmq)) || foreignpkgs=(${pkgs[@]})
        if [[ -n "${foreignpkgs[@]}" ]]; then
            SetJson ${foreignpkgs[@]}
            aurpkgsAname=($(GetJson "var" "$json" "Name"))
            aurpkgsAver=($(GetJson "var" "$json" "Version"))
            aurpkgsQver=($(expac -Q '%v' ${aurpkgsAname[@]}))
            for i in "${!aurpkgsAname[@]}"; do
                [[ $(vercmp "${aurpkgsAver[$i]}" "${aurpkgsQver[$i]}") -gt 0 ]] && aurpkgsQood+=(${aurpkgsAname[$i]});
            done
        fi

        # add devel packages
        if [[ $devel ]]; then
            if [[ ! $needed ]]; then
                for i in "${foreignpkgs[@]}"; do
                    [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|nightly.*)$" <<< $i)" ]] && aurpkgsQood+=($i)
                done
            else
                foreignpkgsbase=($(expac -Q '%n %e' ${foreignpkgs[@]} | awk '{if ($2 == "(null)") print $1; else print $2}'))
                foreignpkgsnobase=($(expac -Q '%n' ${foreignpkgs[@]}))
                for i in "${!foreignpkgsbase[@]}"; do
                    if [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|nightly.*)$" <<< ${foreignpkgsbase[$i]})" ]]; then
                        [[ ! -d "$clonedir/${foreignpkgsbase[$i]}" ]] && DownloadPkgs "${foreignpkgsbase[$i]}" &>/dev/null
                        cd "$clonedir/${foreignpkgsbase[$i]}"# silent extraction and pkgver update only
                        makepkg -od --noprepare --skipinteg &>/dev/null
                        # retrieve updated version
                        aurdevelpkgsAver=($(makepkg --packagelist | awk -F "-" '{print $(NF-2)"-"$(NF-1)}'))
                        aurdevelpkgsAver=${aurdevelpkgsAver[0]}
                        aurdevelpkgsQver=$(expac -Qs '%v' "^${foreignpkgsbase[$i]}$" | head -1)
                        if [[ $(vercmp "$aurdevelpkgsQver" "$aurdevelpkgsAver") -ge 0 ]]; then
                            continue
                        else
                            aurpkgsQood+=(${foreignpkgsnobase[$i]})
                            aurpkgsQoodAver+=($aurdevelpkgsAver)
                        fi
                    fi
                done
            fi
        fi

        if [[ -n "${aurpkgsQood[@]}" && ! $quiet ]]; then
            SetJson ${aurpkgsQood[@]}
            aurpkgsAname=($(GetJson "var" "$json" "Name"))
            aurpkgsAname=($(expac -Q '%n' "${aurpkgsAname[@]}"))
            aurpkgsAver=($(GetJson "var" "$json" "Version"))
            aurpkgsQver=($(expac -Q '%v' "${aurpkgsAname[@]}"))
            for i in "${!aurpkgsAname[@]}"; do
                [[ " ${ignoredpkgs[@]} " =~ " ${aurpkgsAname[$i]} " ]] && aurpkgsQignore[$i]=$"[ ignored ]"
                if [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|nightly.*)$" <<< ${aurpkgsAname[$i]})" ]]; then
                    [[ ! $needed ]] && aurpkgsAver[$i]=$"latest"
                fi
            done
            lAname=$(GetLength "${aurpkgsAname[@]}")
            lAQver=$(GetLength "${aurpkgsQver[@]}")
            lASver=$(GetLength "${aurpkgsAver[@]}")
            lArepo=3
        fi
    fi

    if [[ ! "${opts[@]}" =~ "m" && ! " ${pacopts[@]} " =~ --foreign ]]; then
        [[ -n "${pkgs[@]}" ]] && pkgs=($(expac -Q '%n' "${pkgs[@]}"))
        repopkgsQood=($($pacmanbin -Qunq ${pkgs[@]}))

        if [[ -n "${repopkgsQood[@]}" && ! $quiet ]]; then
            repopkgsQver=($(expac -Q '%v' "${repopkgsQood[@]}"))
            repopkgsSver=($(expac -S -1 '%v' "${repopkgsQood[@]}"))
            repopkgsSrepo=($(expac -S -1 '%r' "${repopkgsQood[@]}"))
            repopkgsQgrp=($(expac -Qv -l "#" '(%G)' "${repopkgsQood[@]}"))
            for i in "${!repopkgsQood[@]}"; do
                [[ "${repopkgsQgrp[$i]}" = '(None)' ]] && unset repopkgsQgrp[$i] || repopkgsQgrp[$i]=$(tr '#' ' ' <<< ${repopkgsQgrp[$i]})
                [[ " ${ignoredpkgs[@]} " =~ " ${repopkgsQood[$i]} " ]] && repopkgsQignore[$i]=$"[ ignored ]"
            done
            lname=$(GetLength "${repopkgsQood[@]}")
            lQver=$(GetLength "${repopkgsQver[@]}")
            lSver=$(GetLength "${repopkgsSver[@]}")
            lrepo=$(GetLength "${repopkgsSrepo[@]}")
            lgrp=$(GetLength "${repopkgsQgrp[@]}")
        fi
    fi

    if [[ -n "${aurpkgsQood[@]}" && ! $quiet ]]; then
        [[ $lAname -gt $lname ]] && lname=$lAname
        [[ $lAQver -gt $lQver ]] && lQver=$lAQver
        [[ $lASver -gt $lSver ]] && lSver=$lASver
    fi

    if [[ -n "${repopkgsQood[@]}" ]]; then
        exitrepo=$?
        if [[ ! $quiet ]]; then
            for i in "${!repopkgsQood[@]}"; do
                printf "${colorB}::${reset} ${colorM}%-${lrepo}s${reset}  ${colorW}%-${lname}s${reset}  ${colorR}%-${lQver}s${reset}  ->  ${colorG}%-${lSver}s${reset}  ${colorB}%-${lgrp}s${reset}  ${colorY}%s${reset}\n" "${repopkgsSrepo[$i]}" "${repopkgsQood[$i]}" "${repopkgsQver[$i]}" "${repopkgsSver[$i]}" "${repopkgsQgrp[$i]}" "${repopkgsQignore[$i]}"
            done
        else
            tr ' ' '\n' <<< ${repopkgsQood[@]}
        fi
    fi
    if [[ -n "${aurpkgsQood[@]}" && $fallback = true ]]; then
        exitaur=$?
        if [[ ! $quiet ]]; then
            for i in "${!aurpkgsAname[@]}"; do
                printf "${colorB}::${reset} ${colorM}%-${lrepo}s${reset}  ${colorW}%-${lname}s${reset}  ${colorR}%-${lQver}s${reset}  ->  ${colorG}%-${lSver}s${reset}  ${colorB}%-${lgrp}s${reset}  ${colorY}%s${reset}\n" "aur" "${aurpkgsAname[$i]}" "${aurpkgsQver[$i]}" "${aurpkgsAver[$i]}" " " "${aurpkgsQignore[$i]}"
            done
        else
            tr ' ' '\n' <<< ${aurpkgsQood[@]} | sort -u
        fi
    fi
    # exit code
    if [[ -n "$exitrepo" && -n "$exitaur" ]]; then
        [[ $exitrepo -eq 0 || $exitaur -eq 0 ]] && exit 0 || exit 1
    elif [[ -n "$exitrepo" ]]; then
        [[ $exitrepo -eq 0 ]] && exit 0 || exit 1
    elif [[ -n "$exitaur" ]]; then
        [[ $exitaur -eq 0 ]] && exit 0 || exit 1
    else
        exit 1
    fi
}

##
# Upgrade needed AUR packages.
#
# usage: UpgradeAur()
##
UpgradeAur() {
    local foreignpkgs allaurpkgs allaurpkgsAver allaurpkgsQver aurforeignpkgs i json
    # global aurpkgs
    Note "i" $"${colorW}Starting AUR upgrade...${reset}"

    # selective upgrade switch
    if [[ $selective && -n ${pkgs[@]} ]]; then
        aurpkgs+=(${pkgs[@]})
    else
        foreignpkgs=($($pacmanbin -Qmq))
        SetJson ${foreignpkgs[@]}
        allaurpkgs=($(GetJson "var" "$json" "Name"))
        allaurpkgsAver=($(GetJson "var" "$json" "Version"))
        allaurpkgsQver=($(expac -Q '%v' ${allaurpkgs[@]}))
        for i in "${!allaurpkgs[@]}"; do
            [[ $(vercmp "${allaurpkgsAver[$i]}" "${allaurpkgsQver[$i]}") -gt 0 ]] && aurpkgs+=(${allaurpkgs[$i]});
        done
    fi

    # foreign packages check
    aurforeignpkgs=($(grep -xvf <(printf '%s\n' "${allaurpkgs[@]}") <(printf '%s\n' "${foreignpkgs[@]}")))
    for i in "${aurforeignpkgs[@]}"; do
        Note "w" $"${colorW}$i${reset} is ${colorY}not present${reset} in AUR -- skipping"
    done

    # add devel packages
    if [[ $devel ]]; then
        for i in "${allaurpkgs[@]}"; do
            [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|nightly.*)$" <<< $i)" ]] && aurpkgs+=($i)
        done
    fi

    # avoid possible duplicate
    aurpkgs=($(tr ' ' '\n' <<< ${aurpkgs[@]} | sort -u))

    NothingToDo ${aurpkgs[@]}
}

##
# Search packages in the AUR
#
# usage: SearchAur( $packages )
##
SearchAur() {
    if [[ -z "$(grep -E "\-\-[r]?sort" <<< ${coweropts[@]})" ]]; then
        [[ $sortorder = descending ]] && coweropts+=("--rsort=$sortby") || coweropts+=("--sort=$sortby");
    fi
    cower ${coweropts[@]} -- $@
}

##
# Fetch and print formatted information of AUR packages
#
# usage: InfoAur( $aur_packages )
##
InfoAur() {
    local aurinfopkgs info infolabel maxlength linfo lbytes

    readarray aurinfopkgs < <(cower ${coweropts[@]} --format "%n|%v|%d|%u|%p|%L|%W|%G|%P|%D|%M|%O|%C|%R|%m|%r|%o|%t|%w|%s|%a\n" $@)
    aurinfopkgsQname=($(expac -Q '%n' $@))
    aurinfopkgsQver=($(expac -Q '%v' $@))

    infolabel=($"Repository" $"Name" $"Version" $"Description" $"URL" $"AUR Page" $"Licenses" $"Keywords" $"Groups" $"Provides" $"Depends on" \
        $"Make Deps" $"Optional Deps" $"Conflicts With" $"Replaces" $"Maintainer" $"Popularity" $"Votes" $"Out of Date" $"Submitted" $"Last Modified")
    linfo=$(GetLength "${infolabel[@]}")
    # take into account differences between characters and bytes
    for i in "${!infolabel[@]}"; do
        (( lbytes[$i] = $(printf "${infolabel[$i]}" | wc -c) - ${#infolabel[$i]} + ${linfo} ))
    done
    maxlength=$(($(tput cols) - $linfo - 4))

    for i in "${!aurinfopkgs[@]}"; do
        IFS='|' read -ra info <<< "${aurinfopkgs[$i]}"
        # repo
        printf "${colorW}%-${lbytes[0]}s  :${reset} ${colorM}aur${reset}\n" "${infolabel[0]}"
        # name and installed status
        if [[ " ${aurinfopkgsQname[@]} " =~ " ${info[0]} " ]]; then
            for j in "${!aurinfopkgsQname[@]}"; do
                [[ "${aurinfopkgsQname[$j]}" != "${info[0]}" ]] && continue
                if [[ $(vercmp "${info[1]}" "${aurinfopkgsQver[$j]}") -eq 0 ]]; then
                    printf "${colorW}%-${lbytes[1]}s  :${reset} ${colorW}%s${reset} ${colorC}[${reset}${colorG}%s${reset}${colorC}]${reset}\n" "${infolabel[1]}" "${info[0]}" $"installed"
                elif [[ $(vercmp "${info[1]}" "${aurinfopkgsQver[$j]}") -lt 0 ]]; then
                    printf "${colorW}%-${lbytes[1]}s  :${reset} ${colorW}%s${reset} ${colorC}[${reset}${colorG}%s: %s${reset}${colorC}]${reset}\n" "${infolabel[1]}" "${info[0]}" $"installed" "${aurinfopkgsQver[$j]}"
                else
                    printf "${colorW}%-${lbytes[1]}s  :${reset} ${colorW}%s${reset} ${colorC}[${reset}${colorR}%s: %s${reset}${colorC}]${reset}\n" "${infolabel[1]}" "${info[0]}" $"installed" "${aurinfopkgsQver[$j]}"
                fi
            done
        else
            printf "${colorW}%-${linfo}s  :${reset} ${colorW}%s${reset}\n" "${infolabel[1]}" "${info[0]}"
        fi
        # version
        if [[ "${info[17]}" = 'no' ]]; then
            printf "${colorW}%-${lbytes[2]}s  :${reset} ${colorG}%s${reset}\n" "${infolabel[2]}" "${info[1]}"
        else
            printf "${colorW}%-${lbytes[2]}s  :${reset} ${colorR}%s${reset}\n" "${infolabel[2]}" "${info[1]}"
        fi
        # description
        if [[ $(GetLength "${info[2]}") -gt $maxlength ]]; then
            # add line breaks if needed and align text
            info[2]=$(sed 's/ /  /g' <<< ${info[2]} | fold -s -w $(($maxlength - 2)) | sed "s/^ //;2,$ s/^/\\x1b[$(($linfo + 4))C/")
        fi
        printf "${colorW}%-${lbytes[3]}s  :${reset} %s\n" "${infolabel[3]}" "${info[2]}"
        # url page
        printf "${colorW}%-${lbytes[4]}s  :${reset} ${colorC}%s${reset}\n" "${infolabel[4]}" "${info[3]}"
        printf "${colorW}%-${lbytes[5]}s  :${reset} ${colorC}%s${reset}\n" "${infolabel[5]}" "${info[4]}"
        # keywords licenses dependencies
        for j in {5..13}; do
            if [[ -n $(tr -dc '[[:print:]]' <<< ${info[$j]}) ]]; then
                # handle special optional deps cases
                if [[ "$j" = '11' ]]; then
                    info[$j]=$(sed -r 's/\S+:/\n&/2g' <<< ${info[$j]} | fold -s -w $(($maxlength - 2)) | sed "s/^ //;2,$ s/^/\\x1b[$(($linfo + 4))C/")
                else
                    # add line breaks if needed and align text
                    if [[ $(GetLength "${info[$j]}") -gt $maxlength ]]; then
                        info[$j]=$(sed 's/ /  /g' <<< ${info[$j]} | fold -s -w $(($maxlength - 2)) | sed "s/^ //;2,$ s/^/\\x1b[$(($linfo + 4))C/")
                    fi
                fi
                printf "${colorW}%-${lbytes[$j+1]}s  :${reset} %s\n" "${infolabel[$j+1]}" "${info[$j]}"
            else
                printf "${colorW}%-${lbytes[$j+1]}s  :${reset} %s\n" "${infolabel[$j+1]}" $"None"
            fi
        done
        # maintainer popularity votes
        for j in {14..16}; do
            printf "${colorW}%-${lbytes[$j+1]}s  :${reset} %s\n" "${infolabel[$j+1]}" "${info[$j]}"
        done
        # outofdate
        if [[ "${info[17]}" = 'no' ]]; then
            printf "${colorW}%-${lbytes[18]}s  :${reset} ${colorG}%s${reset}\n" "${infolabel[18]}" $"No"
        else
            printf "${colorW}%-${lbytes[18]}s  :${reset} ${colorR}%s${reset} [%s]\n" "${infolabel[18]}" $"Yes" $"$(date -d "@${info[18]}" "+%c")"
        fi
        # submitted modified
        printf "${colorW}%-${lbytes[19]}s  :${reset} %s\n" "${infolabel[19]}" $"$(date -d "@${info[19]}" "+%c")"
        printf "${colorW}%-${lbytes[20]}s  :${reset} %s\n" "${infolabel[20]}" $"$(date -d "@${info[20]}" "+%c")"
        echo
    done
}
# vim:set ts=4 sw=2 et:
