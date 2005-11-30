#! /bin/sh

svn=$1
shift;
svndiff=$1
shift;
defaultDiffAppIndex=$1
shift;

if [ "$defaultDiffAppIndex" == "2" ]
then
	export appToDoDiffWith="codewarrior"
		
elif [ "$defaultDiffAppIndex" == "1" ]
then	
	export appToDoDiffWith="textwrangler"
else
	export appToDoDiffWith="opendiff" #default : FileMerge
fi

# now invoke svn diff and pass the remaining arguments as-is
"$svn" diff --diff-cmd "$svndiff" "$@" 
# also invoke svn diff normally in order to get some log output. svn diff is thus called twice. Think about making it optional if people complain about it :-)
#"$svn" diff "$@" 2>/dev/null # avoid double stderr
