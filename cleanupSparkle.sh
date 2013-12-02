#!/bin/sh

#  cleanupSparkle.sh
#  Mailboxer
#
#  Created by  Sven on 02.12.13.
#
cd "$BUILT_PRODUCTS_DIR"
echo "$BUILT_PRODUCTS_DIR"
cd "Mailboxer.app/Contents/"

# Sparkle cleanup
# kill headers
cd "Frameworks/Sparkle.framework/"
ls | grep Headers | xargs rm
cd "Versions/A"
ls | grep Headers | xargs rm -r
echo `pwd`

# kill unused localisations
cd "Resources"
find . -name "*.lproj" | grep -v -E "(de|en|fr).lproj" | xargs rm -r

cd ../..