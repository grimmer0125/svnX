#!/bin/sh -e
# svnresolve.sh <svn-tool> <diff-app> <wc-file-path…>

#echo -e "\nsvnresolve '$1' '$2'" >> /tmp/app.txt

svn="$1"
diff="$2"
shift 2

function tag ()
{
	local n=`echo "$xml" | sed -n -E -e "/<$1>(.+)<\\/$1>/ { s//\1/; p; q; }"`
	if [ -z "$n" -o ! -f "$dir/$n" ]; then
		echo "ERROR: Missing $1 for '$f'" >&2
		exit 1
	fi
	echo "$dir/$n"
}

until [ -z "$1" ]; do
	f="$1"
	dir="${1%/*}"
	xml=`"$svn" info --non-interactive --xml "$1" | grep -e '-file>'`
	left=`tag 'prev-wc-file'`
	right=`tag 'cur-base-file'`
	base=`tag 'prev-base-file'`

	#echo -e "\t'$1'\n\tleft='$left'\n\tright='$right'\n\tbase='$base'" >> /tmp/app.txt


	case "$diff" in
	#	"codewarrior"   ) codewarrior_diff "$file1" "$file2" ;;
	#	"textwrangler"  ) /usr/bin/twdiff --case-sensitive "$file1" "$file2" ;;
	#	"bbedit"        ) /usr/bin/bbdiff --case-sensitive "$file1" "$file2" ;;
		"araxis"        ) /usr/local/bin/araxissvndiff3 "$left" "$base" "$right" "$left" "$base" "$right" ;;
	#	"diffmerge"     ) /usr/local/bin/diffmerge.sh -ro1 --title1="$file1" --title2="$file2" "$file1" "$file2" ;;
	#	"changes"       ) /usr/bin/chdiff "$file1" "$file2" ;;
		"guiffy"        ) /usr/local/bin/guiffy -s "$left" "$right" "$base" "$1" ;;
		"kdiff3"        ) ~/bin/kdiff3 "$base" "$left" "$right" --output "$1" ;;
		"filemerge" | * ) DIFF='/usr/bin/opendiff'; if [ ! -x "$DIFF" ]; then DIFF="/Developer$DIFF"
							if [ ! -x "$DIFF" ]; then DIFF='opendiff'; fi; fi
							"$DIFF" "$left" "$right" -ancestor "$base" -merge "$1" ;;
	esac
	shift
done

exit 0

