#! /bin/sh
# svncopy.sh <svn-tool> <options> <destination> <url...>

svn="$1"; options="$2"; destination="$3"
shift 3

until [ -z "$1" ]; do
	# Leave $options unquoted because it may contain multiple options
	"$svn" copy $options "$1" "$destination"
	shift
done

