#!/bin/bash

##
# Test command given as argument.
#
# $1 = command
##
test_command()
{
    COMMAND="$1 &> /dev/null"
    if eval $COMMAND;then
        echo OK
    else
        echo FAILED
        ANY_FAILED=true
    fi
}

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
# Use this repository pacaur script by default
if [ -z ${PACAUR} ]; then PACAUR="${SCRIPTPATH::-5}pacaur"; fi
# Track any error
ANY_FAILED=false
# Packages to be processed
PACKAGES="shellcheck-static"

echo "Testing operation with packages:"
echo -n "Update system..."
test_command "${PACAUR} -Syu --noconfirm"
echo -n "Install packages..."
test_command "${PACAUR} -S --noconfirm --noedit ${PACKAGES}"
echo -n "Uninstall packages..."
test_command "${PACAUR} -R --noconfirm ${PACKAGES}"

if ${ANY_FAILED}; then exit 1; else exit 0; fi
