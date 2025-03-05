#!/bin/bash

# Function to print usage
usage() {
    echo "Usage: $0 <repository> <file_pattern>"
    echo "Example: $0 owner/repo 'fagram-v*.tar.gz'"
    exit 1
}

# Check if the correct number of arguments is provided
#if [ $# -ne 2 ]; then
#    usage
#fi

# Assign arguments to variables
#REPOSITORY=$1
#FILE_PATTERN=$2
REPOSITORY='FajoX1/fagramdesktop'
FILE_PATTERN='fagram-v*.tar.gz'


# Check if latestversion file exists
if [ ! -f latestversion ]; then
    echo "Error: 'latestversion' file not found in the current directory."
    exit 1
fi

# Read the current version from the latestversion file
CURRENT_VERSION=$(cat latestversion)

# GitHub API URL to get the latest release information
LATEST_RELEASE_URL="https://api.github.com/repos/$REPOSITORY/releases/latest"

# Get the latest release information
LATEST_RELEASE_INFO=$(curl -s $LATEST_RELEASE_URL)

# Extract the tag name of the latest release
LATEST_VERSION=$(echo "$LATEST_RELEASE_INFO" | jq -r '.tag_name')
VER_NO=$(echo $LATEST_VERSION | cut -f 2 -d "v")

# Compare versions
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    echo "The latest version ($LATEST_VERSION) is already downloaded."
    exit 0
fi

# Extract the list of assets with their names and download URLs
ASSETS=$(echo "$LATEST_RELEASE_INFO" | jq -c '.assets[]')

# Find the file that matches the pattern
DOWNLOAD_URL=""
FILE_NAME=""

while IFS= read -r asset; do
    NAME=$(echo "$asset" | jq -r '.name')
    URL=$(echo "$asset" | jq -r '.browser_download_url')

    if [[ "$NAME" == $FILE_PATTERN ]]; then
        FILE_NAME="$NAME"
        DOWNLOAD_URL="$URL"
        break
    fi
done <<< "$ASSETS"

# Check if the download URL was found
if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: No file matching pattern '$FILE_PATTERN' found in the latest release of repository '$REPOSITORY'"
    exit 1
fi

# Cleanup
rm -rf *.deb *.gz usr fagram

# Download the file
curl -L -o "$FILE_NAME" "$DOWNLOAD_URL"

# Update the latestversion file with the new version
echo "$LATEST_VERSION" > latestversion
echo "Downloaded $FILE_NAME from the latest release ($LATEST_VERSION) of repository $REPOSITORY"

rm -rf usr fagram
tar -xvf fagram*.tar.gz
mkdir -p fagram/DEBIAN
cp -r usr fagram/
rm -rf fagram/usr/share/metainfo
rm -rf fagram/usr/share/dbus-1
mv fagram/usr/share/applications/*.desktop fagram/usr/share/applications/fagram.desktop
cat <<EOF >> fagram/DEBIAN/control
Package: fagram
Architecture: amd64
Maintainer: @burhanverse
Priority: optional
Version: $VER_NO
Description: FAgram Desktop is a custom Telegram client
EOF
chmod +x fagram/usr/bin/fagram
chmod +x fagram/usr/share/applications/*.desktop
sed -i 's/Name=fagram/Name=fagram/g' fagram/usr/share/applications/fagram.desktop
dpkg-deb -b fagram


# Clean dirs
rm -rf fagram/ usr/ *.tar.gz
rm -rf apt/

# Create dirs
mkdir -p apt/repo/conf
mkdir -p apt/incoming

# Repo setup
cat <<EOF >> apt/repo/conf/distributions
Origin: fagram
Label: fagram Github Apt Repo
Suite: stable
Codename: bionic
Architectures: amd64
Components: main
SignWith: yes
Description: fagram x64 github Apt repository
EOF

mv fagram.deb apt/incoming/fagram_${VER_NO}_amd64.deb

cd apt/repo

reprepro -V \
    --section utils \
    --component main \
    --priority 0 \
    includedeb bionic ../incoming/fagram_${VER_NO}_amd64.deb

cd ..
cd ..

# Commit changes
git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"
git add latestversion apt/repo/
git commit -m "$LATEST_VERSION"