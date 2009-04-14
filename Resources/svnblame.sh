#!/bin/csh
# svnblame.sh <svn-tool> <open-app> <revision> <options> <url...>

set svn="$1";		shift
set openApp="$1";	shift
set revision="$1";	shift
set options="$1"

while ($# > 1)
	shift

	set destination="/tmp/svnx blame ${1:t:r}.r${revision}.${1:e}"
	set n=0
	while (-e "$destination")
		@ n--
		set destination="/tmp/svnx$n blame ${1:t:r}.r${revision}.${1:e}"
	end

	"$svn" blame -r $revision $options "$1" > "$destination"

	/usr/bin/open $openApp "$destination"
	#unlink "$destination"
end

