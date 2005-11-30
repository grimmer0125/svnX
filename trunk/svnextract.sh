#! /bin/sh
#echo "$@" > /tmp/svntest.txt
svn=$1
shift;
options=$1
shift;

until [ -z "$1" ]
do
	operation=$1
	shift

	source=$1
	shift

	destination=$1
	shift

	if [ "$operation" == "e" ]
	then
		# it's important to leave $options without surrounding quotes because $options contains an arbitrary number of options that should be seen as several items
		"$svn" export $options --force "$source" "$destination"
		
	else

		"$svn" cat $options  "$source" > "$destination"
	fi
done

exit 0