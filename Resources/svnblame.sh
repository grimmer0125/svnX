#! /bin/sh
# svnblame.sh <svn-tool> <diff-app> <revision> <options> <url...>

open_sh="${0%/*}/open.sh"
svn="$1"; diff="$2"; revision="$3"; options="$4"
shift 4

until [ -z "$1" ]
do
	name=`"$svn" info "$1" | grep -m 1 '^Name: ' | colrm 1 6`
	if [ "${name##*.}" == "$name" ]; then
		name="${name%.*}-r$revision"
	else
		name="${name%.*}-r$revision.${name##*.}"
	fi
	destination="/tmp/svnx-$$-blame-$name"
	n=0
	while [ -e "$destination" ]
	do
		n=$((n + 1))
		destination="/tmp/svnx-$$-blame-${n}-$name"
	done

	"$svn" blame -r $revision $options "$1" > "$destination"

	"$open_sh" "$diff" '2' "$destination"
	#unlink "$destination"

	shift
done

