#!/bin/sh

TARGET=/Volumes/svnX

hdiutil create -volname "svnX" -size 10m -fs HFS+ /tmp/svnX.dmg
hdiutil attach -owners on /tmp/svnX.dmg -shadow
ditto build/Deployment/svnX.app "$TARGET"/svnX.app
cp Documentation.rtf "$TARGET"/Read\ Me.rtf
cp License.rtf "$TARGET"/
cp History.rtf "$TARGET"/
#mkdir "$TARGET"/sources
#rsync -avz --exclude .svn --exclude *~.nib --exclude build . "$TARGET"/sources
hdiutil detach "$TARGET"
hdiutil convert -format UDZO /tmp/svnX.dmg -shadow -o ~/Desktop/svnX.dmg
#gzip ~/Desktop/svnX.dmg  
#rm /tmp/svnX.dmg
rm /tmp/svnX.dmg.shadow