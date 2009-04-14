#!/bin/sh

VOLNAME="svnX sources"
TARGET=/Volumes/"$VOLNAME"

hdiutil create -volname "$VOLNAME" -size 10m -fs HFS+ /tmp/svnX-sources.dmg
hdiutil attach -owners on /tmp/svnX-sources.dmg -shadow
cp License.rtf "$TARGET"/
mkdir "$TARGET"/sources
rsync -avz --exclude .svn --exclude *~.nib --exclude build . "$TARGET"/sources
hdiutil detach "$TARGET"
hdiutil convert -format UDZO /tmp/svnX-sources.dmg -shadow -o ~/Desktop/svnX-sources.dmg
#gzip ~/Desktop/svnX-sources.dmg  
#rm /tmp/svnX-sources.dmg
rm /tmp/svnX-sources.dmg.shadow