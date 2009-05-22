#! /bin/sh
#
# open.sh <diff-app> '2' <files...>
#

openX=~/.subversion/svnXopen.sh
if [ -x $openX -a "$0" != $openX ]; then
	if { $openX "$@"; } then exit; fi
fi

alias Open='/usr/bin/open'
DIFF="$1"
shift $2

PICT='Preview'
CS2P='Adobe Photoshop CS2'
FOTO='com.adobe.Photoshop'
TEXT='TextEdit'
WORD='TextEdit'
CODE='Xcode'
apps=`ps -cxo command`

if [ \( -z "${apps##*TextWrangler*}" \) -o $DIFF = 'textwrangler' ]; then
	TEXT='TextWrangler'
elif [ \( -z "${apps##*BBEdit*}" \) -o $DIFF = 'bbedit' ]; then
	TEXT='BBEdit'
elif [ -z "${apps##*TextMate*}" ]; then
	TEXT='TextMate'
fi

if [ -z "${apps##*Xcode*}" ]; then
	CODE='Xcode'
elif [ \( -z "${apps##*CodeWarrior*}" \) -o $DIFF = 'codewarrior' ]; then
	CODE='CodeWarrior IDE'
elif [ \( -z "${apps##*TextWrangler*}" \) -o $DIFF = 'textwrangler' ]; then
	CODE='TextWrangler'
elif [ \( -z "${apps##*BBEdit*}" \) -o $DIFF = 'bbedit' ]; then
	CODE='BBEdit'
elif [ -z "${apps##*TextMate*}" ]; then
	CODE='TextMate'
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


until [ -z "$1" ]; do
#	echo "open <$1>"
	case "${1##*.}" in
		pict|pdf|ps)			openA "$1" "$PICT";;
		gif|jpg|png|tif|tiff)	openA "$1" "$PICT";;
		c|h|cp|hp|cpp|hpp|m|mm)	openA "$1" "$CODE";;
		java|M|r)				openA "$1" "$CODE";;
		html|htm|css|xml)		openA "$1" "$TEXT";;
		txt|xsl)				openA "$1" "$TEXT";;
		js|sh|strings)			openA "$1" "$TEXT";;
		doc|rtf)				openA "$1" "$WORD";;
		psd)					openAB "$1" "$CS2P" "$FOTO";;
		*)						Open "$1";;
	esac

	shift
done

