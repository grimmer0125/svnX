#! /bin/sh

svn="$1"
options="$2"
destination="$3"
shift 3

until [ -z "$1" ]
do
	# it's important to leave $options without surrounding quotes because $options
	# contains an arbitrary number of options that should be seen as several items
	"$svn" move $options --force "$1" "$destination"
	shift
done
