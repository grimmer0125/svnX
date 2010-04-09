#! /bin/sh
# svnblame.sh <svn-tool> <diff-app> <revision> <options> [<url> <name>]+

open_sh="${0%/*}/open.sh"
svn="$1"; diff="$2"; revision="$3"; options="$4"
shift 4

dir="/tmp/svnx"; n=0
while ([ ! -d $dir ] && ! mkdir $dir &> /dev/null); do
	dir="/tmp/svnx$((n++))"
done

until [ -z "$1" ]; do
	name="blame r$revision $2"
	destination="$dir/$name";	n=0
	while [ -e "$destination" ]; do
		destination="$dir/$((n++)) $name"
	done

	"$svn" blame -r $revision $options "$1" > "$destination"
	"$open_sh" "$diff" '2' "$destination"
	#unlink "$destination"

	shift 2
done

