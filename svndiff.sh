#!/bin/sh

# Uncomment exactly one of the following 4 lines to set the diff app
#appToDoDiffWith="$SVNX_FILEMERGE_DIFF"
#appToDoDiffWith="$SVNX_CODEWARRIOR_DIFF"
#appToDoDiffWith="$SVNX_TEXTWRANGLER_DIFF"
#appToDoDiffWith="$SVNX_BBEDIT_DIFF"

#echo $@
#until [ -z "$1" ]
#do
#	echo $1
#	shift
#done
#echo "app2: $DIFFAPPINDEX" > /tmp/app.txt

# Sometimes, the temp file created by svn diff is deleted before
# opendiff had a chance to open it...

BASE=`basename "$7"`
fileExt2="${BASE##*.}"

if [ "$fileExt2" == "$BASE" -o "$fileExt2" == "tmp" ]
then
	firstTempFile=/tmp/svnx-opendiff_$$.tmp
	secondTempFile=/tmp/svnx-opendiff2_$$.tmp
else
	firstTempFile=/tmp/svnx-opendiff_$$.tmp."$fileExt2"
	secondTempFile=/tmp/svnx-opendiff2_$$.tmp."$fileExt2"
fi

cp -f "$6" "$firstTempFile"
cp -f "$7" "$secondTempFile"

# Sometimes, svn diff wants us to diff from a tmp file. (don't know why)
# We want to diff the real working copy file.

tmpFileFlag=`echo "$7" | sed -E 's/.*svndiff(\.[0-9]+)?\.tmp$/1/'`
if [ "$tmpFileFlag" == "1" ]
then
	f=`echo "$5" | sed -E 's/(.*)	\(working copy\)$/\1/'`
else
	f=`echo "$7" | sed -e 's/\.svn\/tmp\/\(.*\)\.tmp$/\1/'`
fi

name=$5
workingCopyFlag=${name/*(working copy)/1}

WORKING_COPY="1"
firstFile=$firstTempFile
if [ "$workingCopyFlag" == "$WORKING_COPY" ]
then
	secondFile=$f ; 
	isWorkingCopy=true
else
	secondFile=$secondTempFile
fi

codewarrior_diff()
{
	osascript -e \
	"tell application \"CodeWarrior IDE\" 
		activate
		set fileOne to POSIX file \"$1\" 
		set fileTwo to POSIX file \"$2\" 
		Compare Files fileOne to fileTwo with case sensitive and ignore extra space
	end tell"
}

case "$appToDoDiffWith" in
	"$SVNX_CODEWARRIOR_DIFF" ) codewarrior_diff "$firstFile" "$secondFile" ;;
	"$SVNX_TEXTWRANGLER_DIFF" ) /usr/bin/twdiff --case-sensitive "$firstFile" "$secondFile" ;;
	"$SVNX_BBEDIT_DIFF" ) /usr/bin/bbdiff --case-sensitive "$firstFile" "$secondFile" ;;

	# $SVNX_FILEMERGE_DIFF | * is kind of redundant, as * matches $SVNX_FILEMERGE_DIFF
	# as well, but it makes the code more explicit

	"$SVNX_FILEMERGE_DIFF" | * ) 
		if [ $isWorkingCopy ]
		then 
			/usr/bin/opendiff "$firstFile" "$secondFile" -merge "$secondFile" &> /dev/null
		else 
			/usr/bin/opendiff "$firstFile" "$secondFile"
		fi
		;;
esac
