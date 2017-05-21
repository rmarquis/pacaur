#!/bin/bash
#
#   aur.sh - functions related to AUR operations
#

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
