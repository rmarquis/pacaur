IgnoreChecks() {
    local checkaurpkgs checkaurpkgsAver checkaurpkgsQver i json
    # global aurpkgs rmaurpkgs
    [[ -z "${ignoredpkgs[@]}" ]] && return

    # remove AUR pkgs versioning
    for i in "${!aurpkgs[@]}"; do
        aurpkgsnover[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${aurpkgs[$i]})
    done

    # check targets
    SetJson ${aurpkgsnover[@]}
    checkaurpkgs=($(GetJson "var" "$json" "Name"))
    errdeps+=($(grep -xvf <(printf '%s\n' "${aurpkgsnover[@]}") <(printf '%s\n' "${checkaurpkgs[@]}")))
    errdeps+=($(grep -xvf <(printf '%s\n' "${checkaurpkgs[@]}") <(printf '%s\n' "${aurpkgsnover[@]}")))
    unset aurpkgsnover

    checkaurpkgsAver=($(GetJson "var" "$json" "Version"))
    checkaurpkgsQver=($(expac -Q '%v' "${checkaurpkgs[@]}"))
    for i in "${!checkaurpkgs[@]}"; do
        [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|nightly.*)$" <<< ${checkaurpkgs[$i]})" ]] && checkaurpkgsAver[$i]=$"latest"
    done
    for i in "${!checkaurpkgs[@]}"; do
        if [[ " ${ignoredpkgs[@]} " =~ " ${checkaurpkgs[$i]} " ]]; then
            if [[ ! $upgrade ]]; then
                if [[ ! $noconfirm ]]; then
                    if ! Proceed "y" $"${checkaurpkgs[$i]} is in IgnorePkg/IgnoreGroup. Install anyway?"; then
                        Note "w" $"${colorW}${checkaurpkgs[$i]}${reset}: ignoring package upgrade"
                        rmaurpkgs+=(${checkaurpkgs[$i]})
                        continue
                    fi
                else
                    Note "w" $"${colorW}${checkaurpkgs[$i]}${reset}: ignoring package upgrade"
                    rmaurpkgs+=(${checkaurpkgs[$i]})
                    continue
                fi
            else
                Note "w" $"${colorW}${checkaurpkgs[$i]}${reset}: ignoring package upgrade (${colorR}${checkaurpkgsQver[$i]}${reset} => ${colorG}${checkaurpkgsAver[$i]}${reset})"
                rmaurpkgs+=(${checkaurpkgs[$i]})
                continue
            fi
        fi
        aurpkgsnover+=(${checkaurpkgs[$i]})
    done

    aurpkgs=(${aurpkgsnover[@]})
    NothingToDo ${aurpkgs[@]}
}

ProviderChecks() {
    local allproviders providersdeps providers repodepspkgsprovided providerspkgs provided nb providersnb rmproviderpkgs providerpkgsrm
    # global repodepspkgs repoprovidersconflictingpkgs repodepsSver repodepsSrepo repodepsQver
    [[ -z "${repodepspkgs[@]}" ]] && return

    allproviders=($(expac -S '%S' "${repodepspkgs[@]}" | sort -u))
    # remove installed providers
    providersdeps=($($pacmanbin -T ${allproviders[@]} | sort -u))

    for i in "${!providersdeps[@]}"; do
        providers=($(expac -Ss '%n' "^${providersdeps[$i]}$" | sort -u))
        [[ ! ${#providers[@]} -gt 1 ]] && continue

        # skip if provided in dependency chain
        unset repodepspkgsprovided
        for j in "${!providers[@]}"; do
            [[ " ${repodepspkgs[@]} " =~ " ${providers[$j]} " ]] && repodepspkgsprovided='true'
        done
        [[ $repodepspkgsprovided ]] && continue

        # skip if already provided
        if [[ -n "${providerspkgs[@]}" ]]; then
            providerspkgs=($(tr ' ' '|' <<< ${providerspkgs[@]}))
            provided+=($(expac -Ss '%S' "^(${providerspkgs[*]})$"))
            [[ " ${provided[@]} " =~ " ${providersdeps[$i]} " ]] && continue
        fi

        if [[ ! $noconfirm ]]; then
            Note "i" $"${colorW}There are ${#providers[@]} providers available for ${providersdeps[$i]}:${reset}"
            expac -S -1 '   %!) %n (%r) ' "${providers[@]}"

            local nb=-1
            providersnb=$(( ${#providers[@]} -1 )) # count from 0
            while [[ $nb -lt 0 || $nb -ge ${#providers} ]]; do

                printf "\n%s " $"Enter a number (default=0):"
		case "$TERM" in
		    dumb)
			read -r nb
			;;
		    *)
			read -r -n "$(echo -n $providersnb | wc -m)" nb
			echo
			;;
		esac

                case $nb in
                    [0-9]|[0-9][0-9])
                        if [[ $nb -lt 0 || $nb -ge ${#providers[@]} ]]; then
                            echo && Note "f" $"invalid value: $nb is not between 0 and $providersnb" && ((i--))
                        else
                            break
                        fi;;
                    '') nb=0;;
                    *) Note "f" $"invalid number: $nb";;
                esac
            done
        else
            local nb=0
        fi
        providerspkgs+=(${providers[$nb]})
        [[ $nb -ne 0 ]] && rmproviderpkgs+=(${providersdeps[$i]})
    done

    repoprovidersconflictingpkgs+=(${providerspkgs[@]})

    # pactree always return default choice so update binary deps list
    if [[ -n "${rmproviderpkgs[@]}" ]]; then
        # remove deps of default providers
        for i in "${rmproviderpkgs[@]}"; do
            providerpkgsrm+=($(pactree -su "$i"))
        done
        providerpkgsrm=($($pacmanbin -T ${providerpkgsrm[@]} | sort -u))
        repodepspkgs=($(grep -xvf <(printf '%s\n' "${providerpkgsrm[@]}") <(printf '%s\n' "${repodepspkgs[@]}")))

        # add deps of selected providers instead
        providerspkgs=($(tr '|' ' ' <<< ${providerspkgs[@]}))
        for i in "${providerspkgs[@]}"; do
            providerdeps+=($(pactree -su "$i"))
        done
        repodepspkgs+=($($pacmanbin -T ${providerdeps[@]} | sort -u))
    fi

    # get binary packages info
    if [[ -n "${repodepspkgs[@]}" ]]; then
        repodepspkgs=($(expac -S -1 '%n' "${repodepspkgs[@]}" | LC_COLLATE=C sort -u))
        repodepsSver=($(expac -S -1 '%v' "${repodepspkgs[@]}"))
        repodepsQver=($(expac -Q '%v' "${repodepspkgs[@]}"))
        repodepsSrepo=($(expac -S -1 '%r/%n' "${repodepspkgs[@]}"))
    fi
}

ConflictChecks() {
    local allQprovides allQconflicts Aprovides Aconflicts aurconflicts aurAconflicts Qrequires i j k
    local repodepsprovides repodepsconflicts checkedrepodepsconflicts repodepsconflictsname repodepsconflictsver localver repoconflictingpkgs
    # global deps depsAname json aurdepspkgs aurconflictingpkgs aurconflictingpkgsrm depsQver repodepspkgs repoconflictingpkgsrm repoprovidersconflictingpkgs
    Note "i" $"looking for inter-conflicts..."

    allQprovides=($(expac -Q '%n'))
    allQprovides+=($(expac -Q '%S')) # no versioning
    allQconflicts=($(expac -Q '%C'))

    # AUR conflicts
    Aprovides=(${depsAname[@]})
    Aprovides+=($(GetJson "array" "$json" "Provides"))
    Aconflicts=($(GetJson "array" "$json" "Conflicts"))
    # remove AUR versioning
    for i in "${!Aprovides[@]}"; do
        Aprovides[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${Aprovides[$i]})
    done
    for i in "${!Aconflicts[@]}"; do
        Aconflicts[$i]=$(awk -F ">|<|=" '{print $1}' <<< ${Aconflicts[$i]})
    done
    aurconflicts=($(grep -xf <(printf '%s\n' "${Aprovides[@]}") <(printf '%s\n' "${allQconflicts[@]}")))
    aurconflicts+=($(grep -xf <(printf '%s\n' "${Aconflicts[@]}") <(printf '%s\n' "${allQprovides[@]}")))
    aurconflicts=($(tr ' ' '\n' <<< ${aurconflicts[@]} | LC_COLLATE=C sort -u))

    for i in "${aurconflicts[@]}"; do
        unset aurAconflicts
        [[ " ${depsAname[@]} " =~ " $i " ]] && aurAconflicts=($i)
        for j in "${depsAname[@]}"; do
            [[ " $(GetJson "arrayvar" "$json" "Conflicts" "$j") " =~ " $i " ]] && aurAconflicts+=($j)
        done

        for j in "${aurAconflicts[@]}"; do
            unset k Aprovides
            k=$(expac -Qs '%n %P' "^$i$" | grep -E "([^a-zA-Z0-9_@\.\+-]$i|^$i)" | grep -E "($i[^a-zA-Z0-9\.\+-]|$i$)" | awk '{print $1}')
            [[ ! $installpkg && ! " ${aurdepspkgs[@]} " =~ " $j " ]] && continue # skip if downloading target only
            [[ "$j" == "$k" || -z "$k" ]] && continue # skip if reinstalling or if no conflict exists

            Aprovides=($j)
            if [[ ! $noconfirm && ! " ${aurconflictingpkgs[@]} " =~ " $k " ]]; then
                if ! Proceed "n" $"$j and $k are in conflict ($i). Remove $k?"; then
                    aurconflictingpkgs+=($j $k)
                    aurconflictingpkgsrm+=($k)
                    for l in "${!depsAname[@]}"; do
                        [[ " ${depsAname[$l]} " =~ "$k" ]] && depsQver[$l]=$(expac -Qs '%v' "^$k$")
                    done
                    Aprovides+=($(GetJson "arrayvar" "$json" "Provides" "$j"))
                    # remove AUR versioning
                    for l in "${!Aprovides[@]}"; do
                        Aprovides[$l]=$(awk -F ">|<|=" '{print $1}' <<< ${Aprovides[$l]})
                    done
                    [[ ! " ${Aprovides[@]} " =~ " $k " && ! " ${aurconflictingpkgsrm[@]} " =~ " $k " ]] && CheckRequires $k
                    break
                else
                    Note "f" $"unresolvable package conflicts detected"
                    Note "f" $"failed to prepare transaction (conflicting dependencies)"
                    if [[ $upgrade ]]; then
                        Qrequires=($(expac -Q '%N' "$i"))
                        Note "e" $"$j and $k are in conflict (required by ${Qrequires[*]})"
                    else
                        Note "e" $"$j and $k are in conflict"
                    fi
                fi
            fi
            Aprovides+=($(GetJson "arrayvar" "$json" "Provides" "$j"))
            # remove AUR versioning
            for l in "${!Aprovides[@]}"; do
                Aprovides[$l]=$(awk -F ">|<|=" '{print $1}' <<< ${Aprovides[$l]})
            done
            [[ ! " ${Aprovides[@]} " =~ " $k " && ! " ${aurconflictingpkgsrm[@]} " =~ " $k " ]] && CheckRequires $k
        done
    done

    NothingToDo ${deps[@]}

    # repo conflicts
    if [[ -n "${repodepspkgs[@]}" ]]; then
        repodepsprovides=(${repodepspkgs[@]})
        repodepsprovides+=($(expac -S '%S' "${repodepspkgs[@]}")) # no versioning
        repodepsconflicts=($(expac -S '%H' "${repodepspkgs[@]}"))

        # versioning check
        unset checkedrepodepsconflicts
        for i in "${!repodepsconflicts[@]}"; do
            unset repodepsconflictsname repodepsconflictsver localver
            repodepsconflictsname=${repodepsconflicts[$i]} && repodepsconflictsname=${repodepsconflictsname%[><]*} && repodepsconflictsname=${repodepsconflictsname%=*}
            repodepsconflictsver=${repodepsconflicts[$i]} && repodepsconflictsver=${repodepsconflictsver#*=} && repodepsconflictsver=${repodepsconflictsver#*[><]}
            [[ $repodepsconflictsname ]] && localver=$(expac -Q '%v' $repodepsconflictsname)

            if [[ $localver ]]; then
                case "${repodepsconflicts[$i]}" in
                        *">="*) [[ $(vercmp "$repodepsconflictsver" "$localver") -ge 0 ]] && continue;;
                        *"<="*) [[ $(vercmp "$repodepsconflictsver" "$localver") -le 0 ]] && continue;;
                        *">"*)  [[ $(vercmp "$repodepsconflictsver" "$localver") -gt 0 ]] && continue;;
                        *"<"*)  [[ $(vercmp "$repodepsconflictsver" "$localver") -lt 0 ]] && continue;;
                        *"="*)  [[ $(vercmp "$repodepsconflictsver" "$localver") -eq 0 ]] && continue;;
                esac
                checkedrepodepsconflicts+=($repodepsconflictsname)
            fi
        done

        repoconflicts+=($(grep -xf <(printf '%s\n' "${repodepsprovides[@]}") <(printf '%s\n' "${allQconflicts[@]}")))
        repoconflicts+=($(grep -xf <(printf '%s\n' "${checkedrepodepsconflicts[@]}") <(printf '%s\n' "${allQprovides[@]}")))
        repoconflicts=($(tr ' ' '\n' <<< ${repoconflicts[@]} | LC_COLLATE=C sort -u))
    fi

    for i in "${repoconflicts[@]}"; do
        unset Qprovides
        repoSconflicts=($(expac -S '%n %C %S' "${repodepspkgs[@]}" | grep -E "[^a-zA-Z0-9_@\.\+-]$i" | grep -E "($i[^a-zA-Z0-9\.\+-]|$i$)" | awk '{print $1}'))
        for j in "${repoSconflicts[@]}"; do
            unset k && k=$(expac -Qs '%n %P' "^$i$" | grep -E "([^a-zA-Z0-9_@\.\+-]$i|^$i)" | grep -E "($i[^a-zA-Z0-9\.\+-]|$i$)" | awk '{print $1}')
            [[ "$j" == "$k" || -z "$k" ]] && continue # skip when no conflict with repopkgs

            if [[ ! $noconfirm && ! " ${repoconflictingpkgs[@]} " =~ " $k " ]]; then
                if ! Proceed "n" $"$j and $k are in conflict ($i). Remove $k?"; then
                    repoconflictingpkgs+=($j $k)
                    repoconflictingpkgsrm+=($k)
                    repoprovidersconflictingpkgs+=($j)
                    Qprovides=($(expac -Ss '%S' "^$k$"))
                    [[ ! " ${Qprovides[@]} " =~ " $k " && ! " ${repoconflictingpkgsrm[@]} " =~ " $k " ]] && CheckRequires $k
                    break
                else
                    Note "f" $"unresolvable package conflicts detected"
                    Note "f" $"failed to prepare transaction (conflicting dependencies)"
                    if [[ $upgrade ]]; then
                        Qrequires=($(expac -Q '%N' "$i"))
                        Note "e" $"$j and $k are in conflict (required by ${Qrequires[*]})"
                    else
                        Note "e" $"$j and $k are in conflict"
                    fi
                fi
            fi
            Qprovides=($(expac -Ss '%S' "^$k$"))
            [[ ! " ${Qprovides[@]} " =~ " $k " ]] && CheckRequires $k
        done
    done
}

ReinstallChecks() {
    local i depsAtmp
    # global aurpkgs aurdepspkgs deps aurconflictingpkgs depsAname depsQver depsAver depsAood depsAmain
    depsAtmp=(${depsAname[@]})
    for i in "${!depsAtmp[@]}"; do
        [[ ! $foreign ]] && [[ ! " ${aurpkgs[@]} " =~ " ${depsAname[$i]} " || " ${aurconflictingpkgs[@]} " =~ " ${depsAname[$i]} " ]] && continue
        [[ -z "${depsQver[$i]}" || "${depsQver[$i]}" = '#' || $(vercmp "${depsAver[$i]}" "${depsQver[$i]}") -gt 0 ]] && continue
        [[ ! $installpkg && ! " ${aurdepspkgs[@]} " =~ " ${depsAname[$i]} " ]] && continue
        if [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|nightly.*)$" <<< ${depsAname[$i]})" ]]; then
            Note "w" $"${colorW}${depsAname[$i]}${reset} latest revision -- fetching"
        else
            if [[ ! $needed ]]; then
                Note "w" $"${colorW}${depsAname[$i]}-${depsQver[$i]}${reset} is up to date -- reinstalling"
            else
                Note "w" $"${colorW}${depsAname[$i]}-${depsQver[$i]}${reset} is up to date -- skipping"
                deps=($(tr ' ' '\n' <<< ${deps[@]} | sed "s/^${depsAname[$i]}$//g"))
                unset depsAname[$i] depsQver[$i] depsAver[$i] depsAood[$i] depsAmain[$i]
            fi
        fi
    done
    [[ $needed ]] && depsAname=(${depsAname[@]}) && depsQver=(${depsQver[@]}) && depsAver=(${depsAver[@]}) && depsAood=(${depsAood[@]}) && depsAmain=(${depsAmain[@]})

    NothingToDo ${deps[@]}
}

OutofdateChecks() {
    local i
    # global depsAname depsAver depsAood
    for i in "${!depsAname[@]}"; do
        [[ "${depsAood[$i]}" -gt 0 ]] && Note "w" $"${colorW}${depsAname[$i]}-${depsAver[$i]}${reset} has been flagged ${colorR}out of date${reset} on ${colorY}$(date -d "@${depsAood[$i]}" "+%c")${reset}"
    done
}

OrphanChecks() {
    local i
    # global depsAname depsAver depsAmain
    for i in "${!depsAname[@]}"; do
      [[ "${depsAmain[$i]}" == 'null' ]] && Note "w" $"${colorW}${depsAname[$i]}-${depsAver[$i]}${reset} is ${colorR}orphaned${reset} in AUR"
    done
}

CheckUpdates() {
    local foreignpkgs foreignpkgsbase repopkgsQood repopkgsQver repopkgsSver repopkgsSrepo repopkgsQgrp repopkgsQignore
    local aurpkgsQood aurpkgsAname aurpkgsAver aurpkgsQver aurpkgsQignore i json
    local aurdevelpkgsAver aurdevelpkgsQver aurpkgsQoodAver lname lQver lSver lrepo lgrp lAname lAQver lASver lArepo

    GetIgnoredPkgs

    if [[ ! "${opts[@]}" =~ "n" && ! " ${pacopts[@]} " =~ --native && $fallback = true ]]; then
        [[ -z "${pkgs[@]}" ]] && foreignpkgs=($($pacmanbin -Qmq ${pacopts[@]})) || foreignpkgs=(${pkgs[@]})
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
                for i in "${foreignpkgsbase[@]}"; do
                    if [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|nightly.*)$" <<< $i)" ]]; then
                        [[ ! -d "$clonedir/$i" ]] && DownloadPkgs "$i" &>/dev/null
                        cd "$clonedir/$i"
                        # silent extraction and pkgver update only
                        makepkg -od --noprepare --skipinteg &>/dev/null
                        # retrieve updated version
                        aurdevelpkgsAver=($(makepkg --packagelist | awk -F "-" '{print $(NF-2)"-"$(NF-1)}'))
                        aurdevelpkgsAver=${aurdevelpkgsAver[0]}
                        aurdevelpkgsQver=$(expac -Qs '%v' "^$i$")
                        if [[ $(vercmp "$aurdevelpkgsQver" "$aurdevelpkgsAver") -ge 0 ]]; then
                            continue
                        else
                            aurpkgsQood+=($i)
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
                    [[ ! $needed ]] && aurpkgsAver[$i]=$"latest" || aurpkgsAver[$i]=${aurpkgsQoodAver[$i]}
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
        repopkgsQood=($($pacmanbin -Qunq ${pacopts[@]} ${pkgs[@]}))

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
            tr ' ' '\n' <<< ${aurpkgsQood[@]}
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

CheckRequires() {
    local Qrequires
    Qrequires=($(expac -Q '%n %D' | grep -E " $@[\+]*[^a-zA-Z0-9_@\.\+-]+" | awk '{print $1}' | tr '\n' ' '))
    if [[ -n "${Qrequires[@]}" ]]; then
        Note "f" $"failed to prepare transaction (could not satisfy dependencies)"
        Note "e" $"${Qrequires[@]}: requires $@"
    fi
}
