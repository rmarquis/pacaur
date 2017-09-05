#!/bin/bash
#
#   checks.sh - functions related to checking operations
#

##
# Check packages that are ignored on upgrade or installation.
#
# usage: IgnoreChecks()
##
IgnoreChecks() {
    local checkaurpkgs checkaurpkgsAver checkaurpkgsAgrp checkaurpkgsQver checkaurpkgsQgrp i json
    # global aurpkgs rmaurpkgs
    [[ -z "${ignoredpkgs[@]}" && -z "${ignoredgrps[@]}" ]] && return

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
    # set always the latest revision for devel packages since the RPC data is static only
    for i in "${!checkaurpkgs[@]}"; do
        [[ -n "$(grep -E "\-(cvs|svn|git|hg|bzr|darcs|nightly.*)$" <<< ${checkaurpkgs[$i]})" ]] && checkaurpkgsAver[$i]=$"latest"
    done
    for i in "${!checkaurpkgs[@]}"; do
        unset isignored
        if [[ " ${ignoredpkgs[@]} " =~ " ${checkaurpkgs[$i]} " ]]; then
            isignored=true
        # check ignored groups
        elif [[ -n "${ignoredgrps[@]}" ]]; then
            unset checkaurpkgsAgrp checkaurpkgsQgrp
            checkaurpkgsAgrp=($(GetJson "arrayvar" "$json" "Groups" "${checkaurpkgs[$i]}"))
            for j in "${checkaurpkgsAgrp[@]}"; do
                [[ " ${ignoredgrps[@]} " =~ " $j " ]] && isignored=true
            done
            checkaurpkgsQgrp=($(expac -Q '%G' "${checkaurpkgs[$i]}"))
            for j in "${checkaurpkgsQgrp[@]}"; do
                [[ " ${ignoredgrps[@]} " =~ " $j " ]] && isignored=true
            done
        fi

        if [[ $isignored = true ]]; then
            if [[ ! $upgrade ]]; then
                # ask for installing ignored package
                if [[ ! $noconfirm ]]; then
                    if ! Proceed "y" $"${checkaurpkgs[$i]} is in IgnorePkg/IgnoreGroup. Install anyway?"; then
                        Note "w" $"skipping target: ${colorW}${checkaurpkgs[$i]}${reset}"
                        rmaurpkgs+=(${checkaurpkgs[$i]})
                        continue
                    fi
                else
                    Note "w" $"skipping target: ${colorW}${checkaurpkgs[$i]}${reset}"
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

##
# Check ignored packages needed as dependencies.
#
# usage: IgnoreDepsChecks()
##
IgnoreDepsChecks() {
    local i
    # global ignoredpkgs aurpkgs aurdepspkgs aurdepspkgsAgrp aurdepspkgsQgrp repodepspkgsSgrp repodepspkgsQgrp rmaurpkgs deps repodepspkgs
    [[ -z "${ignoredpkgs[@]}" && -z "${ignoredgrps[@]}" ]] && return

    # add checked targets and preserve tsorted order
    deps=(${deps[@]:0:${#aurpkgs[@]}})

    # check repo dependencies
    for i in "${repodepspkgs[@]}"; do
        unset isignored
        if [[ " ${ignoredpkgs[@]} " =~ " $i " ]]; then
            isignored=true
        # check ignored groups
        elif [[ -n "${ignoredgrps[@]}" ]]; then
            unset repodepspkgsSgrp repodepspkgsQgrp
            repodepspkgsSgrp=($(expac -S -1 '%G' "$i"))
            for j in "${repodepspkgsSgrp[@]}"; do
                [[ " ${ignoredgrps[@]} " =~ " $j " ]] && isignored=true
            done
            repodepspkgsQgrp=($(expac -Q '%G' "$i"))
            for j in "${repodepspkgsQgrp[@]}"; do
                [[ " ${ignoredgrps[@]} " =~ " $j " ]] && isignored=true
            done
        fi

        # check unresolved ignored dependencies
        if [[ $isignored = true ]]; then
            if [[ ! $upgrade ]]; then
                Note "w" $"skipping target: ${colorW}$i${reset}"
            else
                Note "w" $"${colorW}$i${reset}: ignoring package upgrade"
            fi
            Note "e" $"Unresolved dependency '${colorW}$i${reset}'"
        fi
    done
    # check aur dependencies
    for i in "${aurdepspkgs[@]}"; do
        # skip already checked dependencies
        [[ " ${aurpkgs[@]} " =~ " $i " ]] && continue
        [[ " ${rmaurpkgs[@]} " =~ " $i " ]] && Note "e" $"Unresolved dependency '${colorW}$i${reset}'"

        unset isignored
        if [[ " ${ignoredpkgs[@]} " =~ " $i " ]]; then
            isignored=true
        # check ignored groups
        elif [[ -n "${ignoredgrps[@]}" ]]; then
            unset aurdepspkgsAgrp aurdepspkgsQgrp
            aurdepspkgsAgrp=($(GetJson "arrayvar" "$json" "Groups" "$i"))
            for j in "${aurdepspkgsAgrp[@]}"; do
                [[ " ${ignoredgrps[@]} " =~ " $j " ]] && isignored=true
            done
            aurdepspkgsQgrp=($(expac -Q '%G' "$i"))
            for j in "${aurdepspkgsQgrp[@]}"; do
                [[ " ${ignoredgrps[@]} " =~ " $j " ]] && isignored=true
            done
        fi

        # check unresolved ignored dependencies
        if [[ $isignored = true ]]; then
            # ask for installing ignored dependencies
            if [[ ! $noconfirm ]]; then
                if ! Proceed "y" $"$i dependency is in IgnorePkg/IgnoreGroup. Install anyway?"; then
                    Note "w" $"skipping target: ${colorW}$i${reset}"
                    Note "e" $"Unresolved dependency '${colorW}$i${reset}'"
                fi
            else
                if [[ ! $upgrade ]]; then
                    Note "w" $"skipping target: ${colorW}$i${reset}"
                else
                    Note "w" $"${colorW}$i${reset}: ignoring package upgrade"
                fi
                Note "e" $"Unresolved dependency '${colorW}$i${reset}'"
            fi
        fi
        deps+=($i)
    done
}
##
# Check providers of packages and dependencies.
#
# usage: ProviderChecks()
##
ProviderChecks() {
    local allproviders providersdeps providers repodepspkgsprovided providerspkgs provided nb providersnb
    # global repodepspkgs repoprovidersconflictingpkgs repodepsSver repodepsSrepo repodepsQver
    [[ -z "${repodepspkgs[@]}" ]] && return

    # filter directly provided deps
    noprovidersdeps=($(expac -S -1 '%n' ${repodepspkgs[@]}))
    providersdeps=($(grep -xvf <(printf '%s\n' "${noprovidersdeps[@]}") <(printf '%s\n' "${repodepspkgs[@]}")))

    # remove installed providers
    providersdeps=($($pacmanbin -T ${providersdeps[@]} | sort -u))

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

        # select providers, select default provider=0 if noconfirm option is set
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
    done

    # add selected providers to repo deps
    repodepspkgs+=(${providerspkgs[@]})

    # add selected providers to repo deps
    repodepspkgs+=(${providerspkgs[@]})

    # store for installation
    repoprovidersconflictingpkgs+=(${providerspkgs[@]})

    FindDepsRepoProvider ${providerspkgs[@]}

    # get repo packages info
    if [[ -n "${repodepspkgs[@]}" ]]; then
        repodepspkgs=($(expac -S -1 '%n' "${repodepspkgs[@]}" | LC_COLLATE=C sort -u))
        repodepsSver=($(expac -S -1 '%v' "${repodepspkgs[@]}"))
        repodepsQver=($(expac -Q '%v' "${repodepspkgs[@]}"))
        repodepsSrepo=($(expac -S -1 '%r/%n' "${repodepspkgs[@]}"))
    fi
}

##
# Check conflicting packages and dependencies.
#
# usage: ConflictChecks()
##
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
            k=$(expac -Qs '%n %P' "^$i$" | head -1 | grep -E "([^a-zA-Z0-9_@\.\+-]$i|^$i)" | grep -E "($i[^a-zA-Z0-9\.\+-]|$i$)" | awk '{print $1}')
            [[ ! $installpkg && ! " ${aurdepspkgs[@]} " =~ " $j " ]] && continue # skip if downloading target only
            [[ "$j" == "$k" || -z "$k" ]] && continue # skip if reinstalling or if no conflict exists

            Aprovides=($j)
            if [[ ! $noconfirm && ! " ${aurconflictingpkgs[@]} " =~ " $k " ]]; then
                if ! Proceed "n" $"$j and $k are in conflict ($i). Remove $k?"; then
                    aurconflictingpkgs+=($j $k)
                    aurconflictingpkgsrm+=($k)
                    for l in "${!depsAname[@]}"; do
                        [[ " ${depsAname[$l]} " =~ "$k" ]] && depsQver[$l]=$(expac -Qs '%v' "^$k$" | head -1)
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
        repodepsprovides+=($(expac -S -1 '%S' "${repodepspkgs[@]}")) # no versioning
        repodepsconflicts=($(expac -S -1 '%H' "${repodepspkgs[@]}"))

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
        repoSconflicts=($(expac -S -1 '%n %C %S' "${repodepspkgs[@]}" | grep -E "[^a-zA-Z0-9_@\.\+-]$i" | grep -E "($i[^a-zA-Z0-9\.\+-]|$i$)" | awk '{print $1}'))
        for j in "${repoSconflicts[@]}"; do
            unset k && k=$(expac -Qs '%n %P' "^$i$" | head -1 | grep -E "([^a-zA-Z0-9_@\.\+-]$i|^$i)" | grep -E "($i[^a-zA-Z0-9\.\+-]|$i$)" | awk '{print $1}')
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

##
# Check and notify which packages are marked to be reinstalled.
#
# usage: ReinstallChecks()
##
ReinstallChecks() {
    local i depsAtmp
    # global aurpkgs aurdepspkgs deps aurconflictingpkgs depsAname depsQver depsAver depsAood depsAmain
    depsAtmp=(${depsAname[@]})
    for i in "${!depsAtmp[@]}"; do
        # check and skip packages with conflicts to avoid false positive
        [[ ! $foreign ]] && [[ ! " ${aurpkgs[@]} " =~ " ${depsAname[$i]} " || " ${aurconflictingpkgs[@]} " =~ " ${depsAname[$i]} " ]] && continue
        [[ -z "${depsQver[$i]}" || "${depsQver[$i]}" = '#' || $(vercmp "${depsAver[$i]}" "${depsQver[$i]}") -gt 0 ]] && continue
        [[ ! $installpkg && ! " ${aurdepspkgs[@]} " =~ " ${depsAname[$i]} " ]] && continue
        # devel packages are not considered, VCS packages version is not checked by design since it is a slow operation
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

##
# Check out of date packages.
#
# usage: OutofdateChecks()
##
OutofdateChecks() {
    local i
    # global depsAname depsAver depsAood
    for i in "${!depsAname[@]}"; do
        [[ "${depsAood[$i]}" -gt 0 ]] && Note "w" $"${colorW}${depsAname[$i]}-${depsAver[$i]}${reset} has been flagged ${colorR}out of date${reset} on ${colorY}$(date -d "@${depsAood[$i]}" "+%c")${reset}"
    done
}

##
# Check orphaned packages.
#
# usage: OrphanChecks()
##
OrphanChecks() {
    local i
    # global depsAname depsAver depsAmain
    for i in "${!depsAname[@]}"; do
      [[ "${depsAmain[$i]}" == 'null' ]] && Note "w" $"${colorW}${depsAname[$i]}-${depsAver[$i]}${reset} is ${colorR}orphaned${reset} in AUR"
    done
}

##
# Check that all dependencies required by the packages are satisfied.
#
# usage: CheckRequires( $packages )
##
CheckRequires() {
    local Qrequires
    Qrequires=($(expac -Q '%n %D' | grep -E " $@[\+]*[^a-zA-Z0-9_@\.\+-]+" | awk '{print $1}' | tr '\n' ' '))
    if [[ -n "${Qrequires[@]}" ]]; then
        Note "f" $"failed to prepare transaction (could not satisfy dependencies)"
        Note "e" $"${Qrequires[@]}: requires $@"
    fi
}
# vim:set ts=4 sw=2 et:
