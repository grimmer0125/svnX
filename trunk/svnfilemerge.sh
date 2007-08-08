#! /bin/sh

# Define some strings to use as constants
SVNX_FILEMERGE_DIFF="opendiff"
SVNX_TEXTWRANGLER_DIFF="textwrangler"
SVNX_CODEWARRIOR_DIFF="codewarrior"
SVNX_BBEDIT_DIFF="bbedit"
SVNX_ARAXISMRGE_DIFF="araxissvndiff"

# Abstract out DiffAppIndex options
filemergeDiffAppIndex=0
textwranglerDiffAppIndex=1
codewarriorDiffAppIndex=2
bbeditDiffAppIndex=3
araxismergeDiffAppIndex=4

svn=$1
shift;
svndiff=$1
shift;
defaultDiffAppIndex=$1
shift;

case "$defaultDiffAppIndex" in
    $bbeditDiffAppIndex ) appToDoDiffWith="$SVNX_BBEDIT_DIFF" ;;
    $codewarriorDiffAppIndex ) appToDoDiffWith="$SVNX_CODEWARRIOR_DIFF" ;;
    $textwranglerDiffAppIndex ) appToDoDiffWith="$SVNX_TEXTWRANGLER_DIFF" ;;
    $araxismergeDiffAppIndex ) appToDoDiffWith="$SVNX_ARAXISMRGE_DIFF" ;;
    * ) appToDoDiffWith="$SVNX_FILEMERGE_DIFF" ;;
esac
export appToDoDiffWith
export SVNX_FILEMERGE_DIFF SVNX_TEXTWRANGLER_DIFF SVNX_CODEWARRIOR_DIFF SVNX_BBEDIT_DIFF SVNX_ARAXISMRGE_DIFF

# now invoke svn diff and pass the remaining arguments as-is
"$svn" diff --diff-cmd "$svndiff" "$@" 
# also invoke svn diff normally in order to get some log output. svn diff is thus called twice. Think about making it optional if people complain about it :-)
#"$svn" diff "$@" 2>/dev/null # avoid double stderr
