#! /bin/sh

SCRIPT_HOME=$0
if [ -n "`readlink $SCRIPT_HOME`" ] ; then
    SCRIPT_HOME="`readlink $SCRIPT_HOME`"
fi
SCRIPT_HOME="`dirname $SCRIPT_HOME`"

VIM=vim
if [ -n "$THEMIS_VIM" ] ; then
    VIM="$THEMIS_VIM"
fi

$VIM -u NONE -i NONE -N -n -e -s -S $SCRIPT_HOME/test-highlightedyank.vim || exit 1
echo "Succeeded."
