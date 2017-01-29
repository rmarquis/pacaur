Core() {
    GetIgnoredPkgs
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
        allaurpkgs=($(GetJson "var" "$json" "Name" | LC_COLLATE=C sort))
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
            [[ $builtpkg ]] && binaryksize=(${binaryksize[@]/${binaryksize[$i]}/0})
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
