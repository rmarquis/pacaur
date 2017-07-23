#!/bin/bash
#
#   main.sh - functions related to top level operations
#

trap Cancel INT

##
# Start core functionality of the application.
#
# usage: Core()
##
Core() {
    GetIgnoredPkgs
    GetIgnoredGrps
    [[ $upgrade ]] && UpgradeAur
    IgnoreChecks
    DepsSolver
    IgnoreDepsChecks
    ProviderChecks
    ConflictChecks
    ReinstallChecks
    OutofdateChecks
    OrphanChecks
    Prompt
    MakePkgs
}

##
# Format output information of the current operation and ask user to continue.
#
# usage: Prompt()
##
Prompt() {
    local i binaryksize sumk summ builtpkg cachedpkgs strname stroldver strnewver strsize action
    local depsver repodepspkgsver strrepodlsize strrepoinsize strsumk strsumm lreposizelabel lreposize
    # global repodepspkgs repodepsSver depsAname depsAver depsArepo depsAcached lname lver lsize deps depsQver repodepspkgs repodepsSrepo repodepsQver repodepsSver

    # compute binary size
    if [[ -n "${repodepspkgs[@]}" ]]; then
        binaryksize=($(expac -S -1 '%k' "${repodepspkgs[@]}"))
        binarymsize=($(expac -S -1 '%m' "${repodepspkgs[@]}"))
        sumk=0
        summ=0
        for i in "${!repodepspkgs[@]}"; do
            GetBuiltPkg "${repodepspkgs[$i]}-${repodepsSver[$i]}" '/var/cache/pacman/pkg'
            [[ $builtpkg ]] && binaryksize[$i]=0
            sumk=$((sumk + ${binaryksize[$i]}))
            summ=$((summ + ${binarymsize[$i]}))
        done
        sumk=$(awk '{ printf("%.2f\n", $1/$2) }' <<< "$sumk 1048576")
        summ=$(awk '{ printf("%.2f\n", $1/$2) }' <<< "$summ 1048576")
    fi

    # cached packages check
    for i in "${!depsAname[@]}"; do
        [[ ! $PKGDEST || $rebuild ]] && break
        GetBuiltPkg "${depsAname[$i]}-${depsAver[$i]}" "$PKGDEST"
        [[ $builtpkg ]] && cachedpkgs+=(${depsAname[$i]}) && depsAcached[$i]=$"(cached)" || depsAcached[$i]=""
        unset builtpkg
    done

    # use output verbosity options from pacman config file
    if [[ -n "$(grep '^VerbosePkgLists' '/etc/pacman.conf')" ]]; then
        straurname=$"AUR Packages  (${#deps[@]})"; strreponame=$"Repo Packages (${#repodepspkgs[@]})"; stroldver=$"Old Version"; strnewver=$"New Version"; strsize=$"Download Size"
        depsArepo=(${depsAname[@]/#/aur/})
        lname=$(GetLength ${depsArepo[@]} ${repodepsSrepo[@]} "$straurname" "$strreponame")
        lver=$(GetLength ${depsQver[@]} ${depsAver[@]} ${repodepsQver[@]} ${repodepsSver[@]} "$stroldver" "$strnewver")
        lsize=$(GetLength "$strsize")

        # local version column cleanup
        for i in "${!deps[@]}"; do
            [[ "${depsQver[$i]}" =~ '#' ]] && unset depsQver[$i]
        done
        # show detailed output
        printf "\n${colorW}%-${lname}s  %-${lver}s  %-${lver}s${reset}\n\n" "$straurname" "$stroldver" "$strnewver"
        for i in "${!deps[@]}"; do
            printf "%-${lname}s  ${colorR}%-${lver}s${reset}  ${colorG}%-${lver}s${reset}  %${lsize}s\n" "${depsArepo[$i]}" "${depsQver[$i]}" "${depsAver[$i]}" "${depsAcached[$i]}";
        done

        # format and print binary size
        if [[ -n "${repodepspkgs[@]}" ]]; then
            for i in "${!repodepspkgs[@]}"; do
                binarysize[$i]=$(awk '{ printf("%.2f\n", $1/$2) }' <<< "${binaryksize[$i]} 1048576")
            done
            printf "\n${colorW}%-${lname}s  %-${lver}s  %-${lver}s  %s${reset}\n\n" "$strreponame" "$stroldver" "$strnewver" "$strsize"
            for i in "${!repodepspkgs[@]}"; do
                printf "%-${lname}s  ${colorR}%-${lver}s${reset}  ${colorG}%-${lver}s${reset}  %${lsize}s\n" "${repodepsSrepo[$i]}" "${repodepsQver[$i]}" "${repodepsSver[$i]}" $"${binarysize[$i]} MiB";
            done
        fi
    else
        # show version
        for i in "${!deps[@]}"; do
            depsver="${depsver}${depsAname[$i]}-${depsAver[$i]}  "
        done
        for i in "${!repodepspkgs[@]}"; do
            repodepspkgsver="${repodepspkgsver}${repodepspkgs[$i]}-${repodepsSver[$i]}  "
        done
        printf "\n${colorW}%-16s${reset} %s\n" $"AUR Packages  (${#deps[@]})" "$depsver"
        [[ -n "${repodepspkgs[@]}" ]] && printf "${colorW}%-16s${reset} %s\n" $"Repo Packages (${#repodepspkgs[@]})" "$repodepspkgsver"
    fi

    # show total download and installed size of the operation
    if [[ -n "${repodepspkgs[@]}" ]]; then
        strrepodlsize=$"Repo Download Size:"; strrepoinsize=$"Repo Installed Size:"; strsumk=$"$sumk MiB"; strsumm=$"$summ MiB"
        lreposizelabel=$(GetLength "$strrepodlsize" "$strrepoinsize")
        lreposize=$(GetLength "$strsumk" "$strsumm")
        printf "\n${colorW}%-${lreposizelabel}s${reset}  %${lreposize}s\n" "$strrepodlsize" "$strsumk"
        printf "${colorW}%-${lreposizelabel}s${reset}  %${lreposize}s\n" "$strrepoinsize" "$strsumm"
    fi

    echo
    [[ $installpkg ]] && action=$"installation" || action=$"download"
    if ! Proceed "y" $"Proceed with $action?"; then
        exit
    fi
}

##
# Print application usage commands.
#
# usage: Usage()
##
Usage() {
    printf "%s\n" $"usage:  pacaur <operation> [options] [target(s)] -- See also pacaur(8)"
    printf "%s\n" $"operations:"
    printf "%s\n" $" pacman extension"
    printf "%s\n" $"   -S, -Ss, -Si, -Sw, -Su, -Sc, -Qu"
    printf "%s\n" $"                    extend pacman operations to the AUR"
    printf "%s\n" $" AUR specific"
    printf "%s\n" $"   -s, --search     search AUR for matching strings"
    printf "%s\n" $"   -i, --info       view package information"
    printf "%s\n" $"   -d, --download   download target(s) -- pass twice to download AUR dependencies"
    printf "%s\n" $"   -m, --makepkg    download and make target(s)"
    printf "%s\n" $"   -y, --sync       download, make and install target(s)"
    printf "%s\n" $"   -u, --update     update AUR package(s)"
    printf "%s\n" $"   -k, --check      check for AUR update(s)"
    printf "%s\n" $" general"
    printf "%s\n" $"   -v, --version    display version information"
    printf "%s\n" $"   -h, --help       display help information"
    echo
    printf "%s\n" $"options:"
    printf "%s\n" $" pacman extension - can be used with the -S, -Ss, -Si, -Sw, -Su, -Sc operations"
    printf "%s\n" $"   -a, --aur        only search, build or install target(s) from the AUR"
    printf "%s\n" $"   -r, --repo       only search, build or install target(s) from the repositories"
    printf "%s\n" $" general"
    printf "%s\n" $"   -e, --edit       edit target(s) PKGBUILD and view install script"
    printf "%s\n" $"   -q, --quiet      show less information for query and search"
    printf "%s\n" $"   --devel          consider AUR development packages upgrade"
    printf "%s\n" $"   --foreign        consider already installed foreign dependencies"
    printf "%s\n" $"   --ignore         ignore a package upgrade (can be used more than once)"
    printf "%s\n" $"   --needed         do not reinstall already up-to-date target(s)"
    printf "%s\n" $"   --noconfirm      do not prompt for any confirmation"
    printf "%s\n" $"   --noedit         do not prompt to edit files"
    printf "%s\n" $"   --rebuild        always rebuild package(s)"
    printf "%s\n" $"   --silent         silence output"
    echo
}

##
# Print application version.
#
# usage: Version()
##
Version() {
    echo "pacaur $version"
}

##
# Delete lock files and exit the application.
#
# usage: Cancel()
##
Cancel() {
    echo
    [[ -e "$tmpdir/pacaur.build.lck" ]] && rm "$tmpdir/pacaur.build.lck"
    [[ -e "$tmpdir/pacaur.sudov.lck" ]] && rm "$tmpdir/pacaur.sudov.lck"
    exit
}
# vim:set ts=4 sw=2 et:
