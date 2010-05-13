#!/bin/sh
# Usage: makeImage [path-to-svnX.app]

RES="${0%/*}"
SOURCE="${RES%/*}"
TARGET=/Volumes/svnX
TMPDMG=/tmp/svnX.dmg

hdiutil create -volname "svnX" -size 10m -fs HFS+ $TMPDMG
hdiutil attach -owners on $TMPDMG -shadow
ditto "${1:-$SOURCE/build/Release/svnX.app}" "$TARGET/svnX.app"
cp "$RES/Documentation.rtf" "$TARGET/Read Me.rtf"
#ln -s "svnX.app/Contents/Resources/Documentation.rtf" "$TARGET/Read Me.rtf"
cp "$RES/License.rtf" "$TARGET/"
cp "$RES/ChangeLog.html" "$TARGET/"
cp "$RES/open.sh" "$TARGET/svnXopen.sh"
mkdir "$TARGET/bg"; cp "$RES/disc.image.png" "$TARGET/bg/b.png"; SetFile -a V "$TARGET/bg"
cp "$RES/disc.DS_Store" "$TARGET/.DS_Store"; SetFile -a V "$TARGET/.DS_Store"
#mkdir "$TARGET"/sources
#rsync -avz --exclude .svn --exclude *~.nib --exclude build . "$TARGET"/sources
hdiutil detach "$TARGET"
hdiutil convert -format UDZO -imagekey zlib-level=9 $TMPDMG -shadow -o ~/Desktop/svnX.dmg
#hdiutil convert -format UDBZ $TMPDMG -shadow -o ~/Desktop/svnX.dmg
#gzip ~/Desktop/svnX.dmg  
rm $TMPDMG
rm $TMPDMG.shadow
