#!/bin/sh

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

if [ "$fileExt2" == "$BASE" ]
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

f=`echo "$7" | sed -e 's/\.svn\/tmp\/\(.*\)\.tmp$/\1/'`

name=$5
isWorkingCopy=${name/*(working copy)/1}

# Uncomment exactly one of these 3 lines

#appToDoDiffWith="codewarrior"
#appToDoDiffWith="opendiff"
#appToDoDiffWith="textwrangler"

if [ "$isWorkingCopy" == "1" ]
then
	if [ "$appToDoDiffWith" == "codewarrior" ]
	then
		osascript -e \
		"tell application \"CodeWarrior IDE\" 
		    activate
		    set fileOne to POSIX file \"$firstTempFile\" 
		    set fileTwo to POSIX file \"$f\" 
		    Compare Files fileOne to fileTwo with case sensitive and ignore extra space
		end tell"
	elif [ "$appToDoDiffWith" == "textwrangler" ]
	then
		/usr/bin/twdiff --case-sensitive "$firstTempFile" "$f"
	else #elif [ "$appToDoDiffWith" == "opendiff" ]
		/usr/bin/opendiff "$firstTempFile" "$f" -merge "$f" &> /dev/null
	fi
else
	if [ "$appToDoDiffWith" == "codewarrior" ]
	then
		osascript -e \
		"tell application \"CodeWarrior IDE\" 
		    activate
		    set fileOne to POSIX file \"$firstTempFile\" 
		    set fileTwo to POSIX file \"$secondTempFile\" 
		    Compare Files fileOne to fileTwo with case sensitive and ignore extra space
		end tell"
	elif [ "$appToDoDiffWith" == "textwrangler" ]
	then
		/usr/bin/twdiff --case-sensitive "$firstTempFile" "$secondTempFile"
	else #elif [ "$appToDoDiffWith" == "opendiff" ]
		/usr/bin/opendiff "$firstTempFile" "$secondTempFile"
	fi
fi
