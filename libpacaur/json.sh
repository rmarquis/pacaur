#!/bin/bash
#
#   json.sh - functions related to JSON operations
#

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
    urlmax=4400
    # ensure the URI length is shorter than 4444 bytes (44 for AUR path)
    if [[ "${#urlargs}" -lt $urlmax ]]; then
        curl -sfg --compressed -C 0 -w "" "https://$aururl$aurrpc$urlargs"
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
        curl -sfg --compressed -C 0 -w "" $urlargs | sed 's/\(]}{\)\([A-Za-z0-9":,]\+[[]\)/,/g;s/\("resultcount":\)\([0-9]\+\)/"resultcount":0/g'
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
# vim:set ts=4 sw=2 et:
