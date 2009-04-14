#!/bin/sh

#echo "svndiff @=[$@]" >> /tmp/app.txt
#echo "
#svndiff
#	$1
#	$2 '$3'
#	$4 '$5'
#	$6
#	$7" >> /tmp/app.txt

get_ext()
{
	r=`echo "$1" | \
	   sed -n -E -e '/^[^	]+\.([^	]+)	.*\(revision ([0-9]+)\)$/ { s//r\2.\1/; p; q; }' \
				 -e '/^[^	]+\.([^	]+)	.*$/ { s//\1/; p; q; }' \
				 -e '/^[^	]+	.*\(revision ([0-9]+)\)$/ { s//r\1.tmp/; p; q; }' \
				 -e '/.*/s//tmp/;p;q'`
}

# Sometimes, the temp file created by svn diff is deleted before
# opendiff had a chance to open it...

get_ext "$3"; file1="/tmp/svnx-$$-diff1.$r"
cp -f "$6" $file1

# Sometimes, svn diff wants us to diff from a tmp file. (don't know why)
# We want to diff the real working copy file.

tmpFileFlag=`echo "$7" | sed -E 's/.*svndiff(\.[0-9]+)?\.tmp$/1/'`
if [ "$tmpFileFlag" == '1' ]; then
	f=`echo "$5" | sed -E 's/(.*)	\(working copy\)$/\1/'`
else
	f=`echo "$7" | sed -e 's/\.svn\/tmp\/\(.*\)\.tmp$/\1/'`
fi

name="$5"
isWorkingCopy="${name/*(working copy)/1}"
isWorkingCopy="${isWorkingCopy/[!1]*/}"

if [ $isWorkingCopy ]; then
	file2=$f
else
	get_ext "$5"; file2="/tmp/svnx-$$-diff2.$r"
	cp -f "$7" $file2
fi

#echo "  isWorkingCopy='$isWorkingCopy'  tmpFileFlag='$tmpFileFlag'
#	f='$f'
#	file1='$file1'
#	file2='$file2'" >> /tmp/app.txt

codewarrior_diff()
{
	osascript -e \
	"set file1 to POSIX file \"$1\"
	set file2 to POSIX file \"$2\"
	tell application \"CodeWarrior IDE\"
		activate
		Compare Files file1 to file2 without case sensitive and ignore extra space
	end tell"
}

case "$1" in
	"codewarrior"   ) codewarrior_diff "$file1" "$file2" ;;
	"textwrangler"  ) /usr/bin/twdiff --case-sensitive "$file1" "$file2" ;;
	"bbedit"        ) /usr/bin/bbdiff --case-sensitive "$file1" "$file2" ;;
	"araxissvndiff" ) /usr/local/bin/araxissvndiff "$file1" "$file2" "$file1" "$file2" ;;
	"opendiff" | *  ) 
		if [ $isWorkingCopy ]; then 
			/usr/bin/opendiff "$file1" "$file2" -merge "$file2" &> /dev/null
		else 
			/usr/bin/opendiff "$file1" "$file2"
		fi
		;;
esac

