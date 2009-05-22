#!/bin/sh
# Usage: makeImage [path-to-svnX.app]

RES="${0%/*}"
SOURCE="${RES%/*}"
TARGET=/Volumes/svnX

hdiutil create -volname "svnX" -size 10m -fs HFS+ /tmp/svnX.dmg
hdiutil attach -owners on /tmp/svnX.dmg -shadow
ditto "${1:-$SOURCE/build/Release/svnX.app}" "$TARGET/svnX.app"
cp "$RES/Documentation.rtf" "$TARGET/Read Me.rtf"
cp "$RES/License.rtf" "$TARGET/"
cp "$RES/ChangeLog.html" "$TARGET/"
cp "$RES/open.sh" "$TARGET/svnXopen.sh"
#mkdir "$TARGET"/sources
#rsync -avz --exclude .svn --exclude *~.nib --exclude build . "$TARGET"/sources
hdiutil detach "$TARGET"
hdiutil convert -format UDZO /tmp/svnX.dmg -shadow -o ~/Desktop/svnX.dmg
#gzip ~/Desktop/svnX.dmg  
rm /tmp/svnX.dmg
rm /tmp/svnX.dmg.shadow
