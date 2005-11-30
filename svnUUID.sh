#! /bin/sh

svn=$1
shift;

a=`$svn info "$@" | grep "^Repository UUID"`
# a = Repository UUID: abff958a-afd4-0310-bce3-79df316efee6

echo ${a#Repository UUID: }
# echo abff958a-afd4-0310-bce3-79df316efee6
