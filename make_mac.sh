#!/bin/sh

# Clone MT source code if not already there
if [ ! -d "minetest-git" ]; then
  git clone https://github.com/minetest/minetest minetest-git
fi

# Update source code and set version string
cd minetest-git
git checkout master --force
git pull
gitver=`git log -1 --format='%cd.%h' --date=short | tr -d -`

# Apply OS X compatibility patch and build binary
# General fixes:
patch -p1 < ../mt2.patch||echo "*** patch 1 failed"
# gettext (Homebrew uses a custom location):
patch -p1 < ../mt3.patch||echo "*** patch 2 failed"
# LuaJIT fix
patch -p1 < ../mt4.patch||echo "*** patch 3 failed"
rm -f CMakeCache.txt
cmake -G Xcode . -DCMAKE_BUILD_TYPE=Release -DENABLE_FREETYPE=on -DENABLE_LEVELDB=on -DENABLE_GETTEXT=on -DENABLE_REDIS=on -DBUILD_SERVER=NO
xcodebuild clean
xcodebuild ARCHS="x86_64"
cp -p bin/Debug/minetest ../releases/minetest.app/Contents/Resources/bin
cd ../releases

# Change library paths in binary to point to bundle directory
./dylibbundler-0.4.4/dylibbundler -x minetest.app/Contents/Resources/bin/minetest -d ./minetest.app/Contents/libs/ -p @executable_path/../../libs/
echo "======== otool ======="

# Print library paths which should now point to the executable path
otool -L minetest.app/Contents/Resources/bin/minetest | grep executable

# Get minetest_game if it is not already there
if [ ! -d "minetest.app/Contents/Resources/bin/share/games/minetest_game" ]; then
  git clone https://github.com/minetest/minetest_game minetest.app/Contents/Resources/bin/share/games/minetest_game
fi

# Update minetest_game from GitHub
(cd minetest.app/Contents/Resources/bin/share/games/minetest_game && git pull)

# Remove shared directories...
(cd minetest.app/Contents/Resources/bin/share && rm -fr builtin client fonts locale textures)

# ...and copy new ones from source code directory
for i in builtin client fonts locale textures
do
cp -pr ../minetest-git/$i minetest.app/Contents/Resources/bin/share
done

# Create updated Info.plist with new version string
sed -e "s/GIT_VERSION/$gitver/g" Info.plist >  minetest.app/Contents/Info.plist

# Compress app bundle as a ZIP file
fname=minetest-osx-bin-$gitver.zip
rm -f $fname
zip -9 -r $fname minetest.app

