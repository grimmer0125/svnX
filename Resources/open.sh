#! /bin/sh
#
# open.sh <diff-app> <files...>
#

openX=~/.subversion/svnXopen.sh
if [ -x $openX ]; then
	if { $openX $@; } then exit; fi
fi

alias Open='/usr/bin/open'
DIFF="$1"
shift

PICT='Preview'
CS2P='Adobe Photoshop CS2'
FOTO='com.adobe.Photoshop'
TEXT='TextWrangler'
WORD='TextEdit'
CODE='Xcode'
if [ -n "`ps -xo command | grep -m 1 '[C]odeWarrior'`" ]; then
	CODE='CodeWarrior IDE'
fi


function openA ()	# file app
{
	Open -a "$2" "$1" || Open "$1"
}

function openB ()	# file bundle
{
	Open -b "$2" "$1" || Open "$1"
}

function openAB ( )	# file app bundle
{
	Open -a "$2" "$1" || Open -b "$3" "$1" || Open "$1"
}

function openBA ( )	# file bundle app
{
	Open -b "$2" "$1" || Open -a "$3" "$1" || Open "$1"
}


until [ -z "$1" ]
do
#	echo "open <$1>"

	case "${1##*.}" in
		pict|pdf|ps)			openA "$1" "$PICT";;
		jpg|png|tif|tiff)		openA "$1" "$PICT";;
		c|h|cp|hp|cpp|hpp|m|M)	openA "$1" "$CODE";;
		html|htm|css|xml)		openA "$1" "$TEXT";;
		xml|xsl)				openA "$1" "$TEXT";;
		js|sh|strings)			openA "$1" "$TEXT";;
		doc|rtf)				openA "$1" "$WORD";;
		psd)					openAB "$1" "$CS2P" "$FOTO";;
		*)						Open "$1";;
	esac

	shift
done

