#! /bin/sh -f
# svnextract.sh <svn-tool> <options> <diff-app-or-empty> [<op> <source> <dest>]...
svn="$1"; options="$2"; diff="$3"; n=0
shift 3

until [ -z "$1" ]
do
	op="$1"; source="$2"; dest="$3"
	shift 3

	# Leave $options unquoted because it may contain multiple options
	if [ $op == 'e' ]; then
		"$svn" export $options --force "$source" "$dest"
	else
		"$svn" cat $options "$source" > "$dest"
	fi
	eval "f$n=\$dest"
	n=$(($n + 1))
done

if [ -n "$diff" -a "$n" -gt 0 ]; then
	"${0%/*}/open.sh" "$diff" "$f0" "$f1" "$f2" "$f3" "$f4" "$f5" "$f6" "$f7" "$f8" "$f9"
fi

