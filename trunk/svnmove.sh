#! /bin/sh

svn=$1
shift;

options=$1
shift;

destination=$1
shift;

until [ -z "$1" ]
do
	# it's important to leave $options without surrounding quotes because $options contains an arbitrary number of options that should be seen as several items
	"$svn" move $options --force  "$1" "$destination"
	shift
done
