#!/bin/bash
#
#   pkgs.sh - functions related to operations with packages
#

##
# Classify the list of packages given into repository packages and AUR packages.
#
# usage: ClassifyPkgs( $packages )
##
ClassifyPkgs() {
    local noaurpkgs norepopkgs
    # global aurpkgs repopkgs
    if [[ $fallback = true ]]; then
        [[ $repo ]] && repopkgs=(${pkgs[@]})
        [[ $aur ]] && aurpkgs=(${pkgs[@]})
        if [[ ! $repo && ! $aur ]]; then
            unset noaurpkgs
            for i in "${pkgs[@]}"; do
                [[ $i == aur/* ]] && aurpkgs+=(${i:4}) && continue # search aur/pkgs in AUR
                noaurpkgs+=($i)
            done
            [[ -n "${noaurpkgs[@]}" ]] && norepopkgs=($(LANG=C $pacmanbin -Sp ${noaurpkgs[@]} 2>&1 >/dev/null | awk '{print $NF}'))
            for i in "${norepopkgs[@]}"; do
                [[ ! " ${noaurpkgs[@]} " =~ [a-zA-Z0-9\.\+-]+\/$i[^a-zA-Z0-9\.\+-] ]] && aurpkgs+=($i) # do not search repo/pkgs in AUR
            done
            repopkgs=($(grep -xvf <(printf '%s\n' "${aurpkgs[@]}") <(printf '%s\n' "${noaurpkgs[@]}")))
        fi
    else
        [[ ! $aur ]] && repopkgs=(${pkgs[@]}) || aurpkgs=(${pkgs[@]})
    fi
}

##
# Download AUR packages into their corresponding clone directory. If the clone
# directory exists, it cleans and updates the package git repository.
#
# usage: DownloadPkgs( $aur_packages )
##
DownloadPkgs() {
    local i
    # global basepkgs
    Note "i" $"${colorW}Retrieving package(s)...${reset}"
    GetPkgbase $@

    # clone
    for i in ${basepkgs[@]}; do
        cd "$clonedir" || exit 1
        if [[ ! -d "$i" ]]; then
            git clone --depth=1 https://aur.archlinux.org/$i.git
        else
            cd "$clonedir/$i" || exit 1
            git reset --hard HEAD -q # updated pkgver of vcs packages prevent pull
            [[ "$displaybuildfiles" = diff ]] && git rev-parse HEAD > ".git/HEAD.prev"
            git pull --ff -q
        fi
    done

    # no results check
    [[ -z "${basepkgs[@]}" ]] && Note "e" $"no results found"
}

##
# Show PKGBUILD and installation scripts of the AUR packages.
#
# usage: EditPkgs( $aur_packages )
##
EditPkgs() {
    local viewed timestamp i j erreditpkg
    # global cachedpkgs installscripts editor
    [[ $noedit ]] && return
    unset viewed
    for i in "$@"; do
        [[ " ${cachedpkgs[@]} " =~ " $i " ]] && continue
        cd "$clonedir/$i" || exit 1
        unset timestamp
        GetInstallScripts $i
        if [[ ! $edit ]]; then
            if [[ ! $displaybuildfiles = none ]]; then
                if [[ $displaybuildfiles = diff && -e ".git/HEAD.prev" ]]; then
                    # show diff
                    diffcmd="git diff $(cut -f1 .git/HEAD.prev) -- . ':!\.SRCINFO'"
                    if [[ -n "$(eval "$diffcmd")" ]]; then
                        if Proceed "y" $"View $i build files diff?"; then
                            eval "$diffcmd"
                            Note "s" $"${colorW}$i${reset} build files diff viewed"
                            viewed='true'
                            (($? > 0)) && erreditpkg+=($i)
                        fi
                    else
                        Note "w" $"${colorW}$i${reset} build files are up-to-date -- skipping"
                    fi
                else
                    # show pkgbuild
                    if Proceed "y" $"View $i PKGBUILD?"; then
                        if [[ -e "PKGBUILD" ]]; then
                            $editor "PKGBUILD" && Note "s" $"${colorW}$i${reset} PKGBUILD viewed"
                            (($? > 0)) && erreditpkg+=($i)
                        else
                            Note "e" $"Could not open ${colorW}$i${reset} PKGBUILD"
                        fi
                    fi
                    # show install script
                    if [[ -n "${installscripts[@]}" ]]; then
                        for j in "${installscripts[@]}"; do
                            if Proceed "y" $"View $j script?"; then
                                if [[ -e "$j" ]]; then
                                    $editor "$j" && Note "s" $"${colorW}$j${reset} script viewed"
                                    (($? > 0)) && erreditpkg+=($i)
                                else
                                    Note "e" $"Could not open ${colorW}$j${reset} script"
                                fi
                            fi
                        done
                    fi
                fi
            fi
        else
            # show pkgbuild and install script
            if [[ -e "PKGBUILD" ]]; then
                $editor "PKGBUILD" && Note "s" $"${colorW}$i${reset} PKGBUILD viewed"
                (($? > 0)) && erreditpkg+=($i)
            else
                Note "e" $"Could not open ${colorW}$i${reset} PKGBUILD"
            fi
            if [[ -n "${installscripts[@]}" ]]; then
                for j in "${installscripts[@]}"; do
                    if [[ -e "$j" ]]; then
                        $editor "$j" && Note "s" $"${colorW}$j${reset} script viewed"
                        (($? > 0)) && erreditpkg+=($i)
                    else
                        Note "e" $"Could not open ${colorW}$j${reset} script"
                    fi
                done
            fi
        fi
    done

    if [[ -n "${erreditpkg[@]}" ]]; then
        for i in "${erreditpkg[@]}"; do
            Note "f" $"${colorW}$i${reset} errored on exit"
        done
        exit 1
    fi

    if [[ $displaybuildfiles = diff && $viewed = true ]]; then
        [[ $installpkg ]] && action=$"installation" || action=$"download"
        if ! Proceed "y" $"Proceed with $action?"; then
            exit
        fi
    fi
}

##
# Build and install AUR packages using 'makepkg'.
#
# usage: MakePkgs()
##
MakePkgs() {
    local oldorphanpkgs neworphanpkgs orphanpkgs oldoptionalpkgs newoptionalpkgs optionalpkgs errinstall
    local pkgsdepslist vcsclients vcschecked aurdevelpkgsAver aurdevelpkgsQver basepkgsupdate checkpkgsdepslist isaurdeps builtpkgs builtdepspkgs i j
    # global deps basepkgs sudoloop pkgsbase pkgsdeps aurpkgs aurdepspkgs depsAver builtpkg errmakepkg repoprovidersconflictingpkgs aurprovidersconflictingpkgs json

    # download
    DownloadPkgs ${deps[@]}
    EditPkgs ${basepkgs[@]}

    # current orphan and optional packages
    oldorphanpkgs=($($pacmanbin -Qdtq))
    oldoptionalpkgs=($($pacmanbin -Qdttq))
    oldoptionalpkgs=($(grep -xvf <(printf '%s\n' "${oldorphanpkgs[@]}") <(printf '%s\n' "${oldoptionalpkgs[@]}")))

    # initialize sudo
    if sudo $pacmanbin -V > /dev/null; then
        [[ $sudoloop = true ]] && SudoV &
    fi

    # split packages support
    for i in "${!pkgsbase[@]}"; do
        for j in "${!deps[@]}"; do
            [[ "${pkgsbase[$i]}" = "${pkgsbase[$j]}" ]] && [[ ! " ${pkgsdeps[@]} " =~ " ${deps[$j]} " ]] && pkgsdeps+=(${deps[$j]})
        done
        pkgsdeps+=("#")
    done
    pkgsdeps=($(sed 's/ # /\n/g' <<< ${pkgsdeps[@]} | tr -d '#' | sed '/^ $/d' | tr ' ' ',' | sed 's/^,//g;s/,$//g'))

    # reverse deps order
    basepkgs=($(awk '{for (i=NF;i>=1;i--) print $i}' <<< ${basepkgs[@]} | awk -F "\n" '{print}'))
    pkgsdeps=($(awk '{for (i=NF;i>=1;i--) print $i}' <<< ${pkgsdeps[@]} | awk -F "\n" '{print}'))

    # integrity check
    for i in "${!basepkgs[@]}"; do
        # get splitted packages list
        pkgsdepslist=($(awk -F "," '{for (k=1;k<=NF;k++) print $k}' <<< ${pkgsdeps[$i]}))

        # cache check
        unset builtpkg
        if [[ -z "$(grep -E "\-(bzr|git|hg|svn|nightly.*)$" <<< ${basepkgs[$i]})" ]]; then
            for j in "${pkgsdepslist[@]}"; do
                depsAver="$(GetJson "varvar" "$json" "Version" "$j")"
                [[ $PKGDEST && ! $rebuild ]] && GetBuiltPkg "$j-$depsAver" "$PKGDEST"
            done
        fi

        # install vcs clients (checking pkgbase extension only does not take fetching specific commit into account)
        unset vcsclients
        vcsclients=($(grep -E "makedepends = (bzr|git|mercurial|subversion)$" "$clonedir/${basepkgs[$i]}/.SRCINFO" | awk -F " " '{print $NF}'))
        for j in "${vcsclients[@]}"; do
            if [[ ! "${vcschecked[@]}" =~ "$j" ]]; then
                [[ -z "$(expac -Qs '%n' "^$j$")" ]] && sudo $pacmanbin -S $j --asdeps --noconfirm
                vcschecked+=($j)
            fi
        done

        if [[ ! $builtpkg || $rebuild ]]; then
            cd "$clonedir/${basepkgs[$i]}" || exit 1
            Note "i" $"Checking ${colorW}${pkgsdeps[$i]}${reset} integrity..."
            if [[ $silent = true ]]; then
                makepkg -f --verifysource ${makeopts[@]} &>/dev/null
            else
                makepkg -f --verifysource ${makeopts[@]}
            fi
            (($? > 0)) && errmakepkg+=(${pkgsdeps[$i]})
            # silent extraction and pkgver update only
            makepkg -od --skipinteg ${makeopts[@]} &>/dev/null
        fi
    done
    if [[ -n "${errmakepkg[@]}" ]]; then
        for i in "${errmakepkg[@]}"; do
            Note "f" $"failed to verify ${colorW}$i${reset} integrity"
        done
        # remove sudo lock
        [[ -e "$tmpdir/pacaur.sudov.lck" ]] && rm "$tmpdir/pacaur.sudov.lck"
        exit 1
    fi

    # set build lock
    [[ -e "$tmpdir/pacaur.build.lck" ]] && Note "e" $"pacaur.build.lck exists in $tmpdir" && exit 1
    touch "$tmpdir/pacaur.build.lck"

    # install provider packages and repo conflicting packages that makepkg --noconfirm cannot handle
    if [[ -n "${repoprovidersconflictingpkgs[@]}" ]]; then
        Note "i" $"Installing ${colorW}${repoprovidersconflictingpkgs[@]}${reset} dependencies..."
        sudo $pacmanbin -S ${repoprovidersconflictingpkgs[@]} --ask 36 --asdeps --noconfirm
    fi

    # main
    for i in "${!basepkgs[@]}"; do

        # get splitted packages list
        pkgsdepslist=($(awk -F "," '{for (k=1;k<=NF;k++) print $k}' <<< ${pkgsdeps[$i]}))

        cd "$clonedir/${basepkgs[$i]}" || exit 1

        # build devel if necessary only (supported protocols only)
        unset aurdevelpkgsAver
        if [[ -n "$(grep -E "\-(bzr|git|hg|svn|nightly.*)$" <<< ${basepkgs[$i]})" ]]; then
            # retrieve updated version
            aurdevelpkgsAver=($(makepkg --packagelist | awk -F "-" '{print $(NF-2)"-"$(NF-1)}'))
            aurdevelpkgsAver=${aurdevelpkgsAver[0]}

            # check split packages update
            unset basepkgsupdate checkpkgsdepslist
            for j in "${pkgsdepslist[@]}"; do
                aurdevelpkgsQver=$(expac -Qs '%v' "^$j$")
                if [[ -n $aurdevelpkgsQver && $(vercmp "$aurdevelpkgsQver" "$aurdevelpkgsAver") -ge 0 ]] && [[ $needed && ! $rebuild ]]; then
                    Note "w" $"${colorW}$j${reset} is up-to-date -- skipping"
                    continue
                else
                    basepkgsupdate='true'
                    checkpkgsdepslist+=($j)
                fi
            done
            if [[ $basepkgsupdate ]]; then
                pkgsdepslist=(${checkpkgsdepslist[@]})
            else
                continue
            fi
        fi

        # check package cache
        for j in "${pkgsdepslist[@]}"; do
            unset builtpkg
            [[ $aurdevelpkgsAver ]] && depsAver="$aurdevelpkgsAver" || depsAver="$(GetJson "varvar" "$json" "Version" "$j")"
            [[ $PKGDEST && ! $rebuild ]] && GetBuiltPkg "$j-$depsAver" "$PKGDEST"
            if [[ $builtpkg ]]; then
                if [[ " ${aurdepspkgs[@]} " =~ " $j " || $installpkg ]]; then
                    Note "i" $"Installing ${colorW}$j${reset} cached package..."
                    sudo $pacmanbin -Ud $builtpkg --ask 36 ${pacopts[@]} --noconfirm
                    [[ ! " ${aurpkgs[@]} " =~ " $j " ]] && sudo $pacmanbin -D $j --asdeps ${pacopts[@]} &>/dev/null
                else
                    Note "w" $"Package ${colorW}$j${reset} already available in cache"
                fi
                pkgsdeps=($(tr ' ' '\n' <<< ${pkgsdeps[@]} | sed "s/^$j,//g;s/,$j$//g;s/,$j,/,/g;s/^$j$/#/g"))
                continue
            fi
        done
        [[ "${pkgsdeps[$i]}" = '#' ]] && continue

        # build
        Note "i" $"Building ${colorW}${pkgsdeps[$i]}${reset} package(s)..."

        # install then remove binary deps
        makeopts=(${makeopts[@]/-r/})

        if [[ ! $installpkg ]]; then
            unset isaurdeps
            for j in "${pkgsdepslist[@]}"; do
                [[ " ${aurdepspkgs[@]} " =~ " $j " ]] && isaurdeps=true
            done
            [[ $isaurdeps != true ]] && makeopts+=("-r")
        fi

        if [[ $silent = true ]]; then
            makepkg -sefc ${makeopts[@]} --noconfirm &>/dev/null
        else
            makepkg -sefc ${makeopts[@]} --noconfirm
        fi

        # error check
        if (($? > 0)); then
            errmakepkg+=(${pkgsdeps[$i]})
            continue  # skip install
        fi

        # retrieve filename
        unset builtpkgs builtdepspkgs
        for j in "${pkgsdepslist[@]}"; do
            unset builtpkg
            [[ $aurdevelpkgsAver ]] && depsAver="$aurdevelpkgsAver" || depsAver="$(GetJson "varvar" "$json" "Version" "$j")"
            GetBuiltPkg "$j-$depsAver" "$clonedir/${basepkgs[$i]}"
            [[ " ${aurdepspkgs[@]} " =~ " $j " ]] && builtdepspkgs+=($builtpkg) || builtpkgs+=($builtpkg)
        done

        # install
        if [[ $installpkg || -z "${builtpkgs[@]}" ]]; then
            Note "i" $"Installing ${colorW}${pkgsdeps[$i]}${reset} package(s)..."
            # metadata mismatch warning
            if [[ -z "${builtdepspkgs[@]}" && -z "${builtpkgs[@]}" ]]; then
                Note "f" $"${colorW}${pkgsdeps[$i]}${reset} package(s) failed to install. Check .SRCINFO for mismatching data with PKGBUILD."
                errinstall+=(${pkgsdeps[$i]})
            else
                sudo $pacmanbin -Ud ${builtdepspkgs[@]} ${builtpkgs[@]} --ask 36 ${pacopts[@]} --noconfirm
            fi
        fi

        # set dep status
        if [[ $installpkg ]]; then
            for j in "${pkgsdepslist[@]}"; do
                [[ ! " ${aurpkgs[@]} " =~ " $j " ]] && sudo $pacmanbin -D $j --asdeps &>/dev/null
                [[ " ${pacopts[@]} " =~ --(asdep|asdeps) ]] && sudo $pacmanbin -D $j --asdeps &>/dev/null
                [[ " ${pacopts[@]} " =~ --(asexp|asexplicit) ]] && sudo $pacmanbin -D $j --asexplicit &>/dev/null
            done
        fi
    done

    # remove AUR deps
    if [[ ! $installpkg ]]; then
        [[ -n "${aurdepspkgs[@]}" ]] && aurdepspkgs=($(expac -Q '%n' "${aurdepspkgs[@]}"))
        if [[ -n "${aurdepspkgs[@]}" ]]; then
            Note "i" $"Removing installed AUR dependencies..."
            sudo $pacmanbin -Rsn ${aurdepspkgs[@]} --noconfirm
        fi
        # readd removed conflicting packages
        [[ -n "${aurconflictingpkgsrm[@]}" ]] && sudo $pacmanbin -S ${aurconflictingpkgsrm[@]} --ask 36 --asdeps --needed --noconfirm
        [[ -n "${repoconflictingpkgsrm[@]}" ]] && sudo $pacmanbin -S ${repoconflictingpkgsrm[@]} --ask 36 --asdeps --needed --noconfirm
    fi

    # remove locks
    rm "$tmpdir/pacaur.build.lck"
    [[ -e "$tmpdir/pacaur.sudov.lck" ]] && rm "$tmpdir/pacaur.sudov.lck"

    # new orphan and optional packages check
    orphanpkgs=($($pacmanbin -Qdtq))
    neworphanpkgs=($(grep -xvf <(printf '%s\n' "${oldorphanpkgs[@]}") <(printf '%s\n' "${orphanpkgs[@]}")))
    for i in "${neworphanpkgs[@]}"; do
        Note "w" $"${colorW}$i${reset} is now an ${colorY}orphan${reset} package"
    done
    optionalpkgs=($($pacmanbin -Qdttq))
    optionalpkgs=($(grep -xvf <(printf '%s\n' "${orphanpkgs[@]}") <(printf '%s\n' "${optionalpkgs[@]}")))
    newoptionalpkgs=($(grep -xvf <(printf '%s\n' "${oldoptionalpkgs[@]}") <(printf '%s\n' "${optionalpkgs[@]}")))
    for i in "${newoptionalpkgs[@]}"; do
        Note "w" $"${colorW}$i${reset} is now an ${colorY}optional${reset} package"
    done

    # makepkg and install failure check
    if [[ -n "${errmakepkg[@]}" || -n "${errinstall[@]}" ]]; then
        for i in "${errmakepkg[@]}"; do
            Note "f" $"failed to build ${colorW}$i${reset} package(s)"
        done
        exit 1
    fi
}

##
# Get the list of ignored packages from pacman and cower configuration files.
#
# usage: GetIgnoredPkgs()
##
GetIgnoredPkgs() {
    # global ignoredpkgs
    ignoredpkgs+=($(grep '^IgnorePkg' '/etc/pacman.conf' | awk -F '=' '{print $NF}' | tr -d "'\""))
    [[ -e "$HOME/.config/cower/config" ]] && ignoredpkgs+=($(grep '^IgnorePkg' "$HOME/.config/cower/config" | awk -F '=' '{print $NF}' | tr -d "'\""))
    ignoredpkgs=(${ignoredpkgs[@]//,/ })
}

##
# Get the complete path of built package.
#
# usage: GetBuiltPkg( $package_ver, $package_dest )
##
GetBuiltPkg() {
    local pkgext
    # global builtpkg
    # check PKGEXT suffixe first, then default .xz suffixe for repository packages in pacman cache
    # and lastly all remaining suffixes in case PKGEXT is locally overridden
    for pkgext in $PKGEXT .pkg.tar.xz .pkg.tar .pkg.tar.gz .pkg.tar.bz2 .pkg.tar.lzo .pkg.tar.lrz .pkg.tar.Z; do
        builtpkg="$2/$1-${CARCH}$pkgext"
        [[ ! -f "$builtpkg" ]] && builtpkg="$2/$1-any$pkgext"
        [[ -f "$builtpkg" ]] && break;
    done
    [[ ! -f "$builtpkg" ]] && unset builtpkg
}

##
# Get packages base from JSON cache.
#
# usage: GetPkgbase( $aur_packages )
##
GetPkgbase() {
    local i
    # global json pkgsbase basepkgs
    SetJson "$@"
    for i in "$@"; do
        pkgsbase+=($(GetJson "varvar" "$json" "PackageBase" "$i"))
    done
    for i in "${pkgsbase[@]}"; do
        [[ " ${basepkgs[@]} " =~ " $i " ]] && continue
        basepkgs+=($i)
    done
}

##
# Get install scripts of the AUR package.
#
# usage: GetInstallScripts( $aur_package )
##
GetInstallScripts() {
    local installscriptspath
    # global installscripts
    [[ ! -d "$clonedir/$1" ]] && return
    unset installscriptspath installscripts
    installscriptspath=($(find "$clonedir/$1/" -maxdepth 1 -name "*.install"))
    [[ -n "${installscriptspath[@]}" ]] && installscripts=($(basename -a ${installscriptspath[@]}))
}

declare -A jsoncache
##
# Configure JSON cache for list of packages.
#
# usage: SetJson( $aur_packages )
##
SetJson() {
    # global json
    if [[ -z "${jsoncache[$@]}" ]]; then
        jsoncache[$@]="$(DownloadJson $@)"
    fi
    json="${jsoncache[$@]}"
}

##
# Download JSON information of the list of packages.
#
# usage: DownloadJson( $aur_packages )
#
# NOTE: This function prints downloaded JSON information, this information can
# be stored in a array. For example:
# json_array[$packages]="$(DownloadJson $packages)"
##
DownloadJson() {
    local urlencodedpkgs urlargs urlcurl urlarg urlmax j
    urlencodedpkgs=($(sed 's/+/%2b/g;s/@/%40/g' <<< $@)) # pkgname consists of alphanum@._+-
    urlarg='&arg[]='
    urlargs="$(printf "$urlarg%s" "${urlencodedpkgs[@]}")"
    urlmax=8125
    # ensure the URI length is shorter than 8190 bytes (52 for AUR path, 13 reserved)
    if [[ "${#urlargs}" -lt $urlmax ]]; then
        curl -sfg --compressed -C 0 "https://$aururl$aurrpc$urlargs"
    else
        # split and merge json stream
        j=0
        for i in "${!urlencodedpkgs[@]}"; do
            if [[ $((${#urlcurl[$j]} + ${#urlencodedpkgs[$i]} + ${#urlarg})) -ge $urlmax ]]; then
                j=$(($j + 1))
            fi
            urlcurl[$j]=${urlcurl[$j]}${urlarg}${urlencodedpkgs[$i]}
        done
        urlargs="$(printf "https://$aururl$aurrpc%s " "${urlcurl[@]}")"
        curl -sfg --compressed -C 0 $urlargs | sed 's/\(]}{\)\([A-Za-z0-9":,]\+[[]\)/,/g;s/\("resultcount":\)\([0-9]\+\)/"resultcount":0/g'
    fi
}

##
# Query information from the JSON cache. This function has several formatting
# options:
#   - "var"     : print output formatted to be stored in a variable, process
#                 the entire JSON cache.
#   - "varvar"  : print output formatted to be stored in a variable, process
#                 only one package.
#   - "array"   : print output formatted to be stored in an array, process
#                 the entire JSON cache.
#   - "arrayvar": print output formatted to be stored in an array, process
#                 only one package.
#
# usage: GetJson( $option, $json_info, $query, {$aur_package} )
#
# NOTE: This function prints formatted JSON information, this information can
# be stored in a array or variable depending on the option given. For example:
# version="$(GetJson "varvar" $json "Version" $package)"
##
GetJson() {
    if json_verify -q <<< "$2"; then
        case "$1" in
            var)
                json_reformat <<< "$2" | tr -d "\", " | grep -Po "$3:.*" | sed -r "s/$3:/$3#/g" | awk -F "#" '{print $2}';;
            varvar)
                json_reformat <<< "$2" | tr -d ", " | sed -e "/\"Name\":\"$4\"/,/}/!d" | \
                tr -d "\"" | grep -Po "$3:.*" | sed -r "s/$3:/$3#/g" | awk -F "#" '{print $2}';;
            array)
                json_reformat <<< "$2" | tr -d ", " | sed -e "/^\"$3\"/,/]/!d" | tr -d '\"' \
                | tr '\n' ' ' | sed "s/] /]\n/g" | cut -d' ' -f 2- | tr -d '[]"' | tr -d '\n';;
            arrayvar)
                json_reformat <<< "$2" | tr -d ", " | sed -e "/\"Name\":\"$4\"/,/}/!d" | \
                sed -e "/^\"$3\"/,/]/!d" | tr -d '\"' | tr '\n' ' ' | cut -d' ' -f 2- | tr -d '[]';;
        esac
    else
        Note "e" $"Failed to parse JSON"
    fi
}
