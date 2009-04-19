#! /bin/sh
# svnblame.sh <svn-tool> <open-app> <revision> <options> <url...>

open_sh="${0%/*}/open.sh"
svn="$1"
openApp="$2"
revision="$3"
options="$4"
shift 4

until [ -z "$1" ]
do
	name="${1##*/}"
	name="${name%@$revision}"
	if [ "${name##*.}" == "$name" ]; then
		name="${name%.*}-r$revision"
	else
		name="${name%.*}-r$revision.${name##*.}"
	fi
	destination="/tmp/svnx-$$-blame-$name"
	n=0
	while [ -e "$destination" ]
	do
		n=$((n - 1))
		destination="/tmp/svnx-$$-blame-${n}-$name"
	done

	"$svn" blame -r $revision $options "$1" > "$destination"

	"$open_sh" "$openApp" "$destination"
	#unlink "$destination"

	shift
done

