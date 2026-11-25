#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$(dirname "$0")"

MSG="" FILE="" VER=""
for a in "$@"; do
  case "$a" in
    file=*) FILE="${a#file=}" ;;
    ver=*)  VER="${a#ver=}" ;;
    *)      MSG="$a" ;;
  esac
done

D=dists/stable/main/binary-all
mkdir -p "$D"

if [ -n "$FILE" ]; then
  [ -f "$FILE" ] || { echo "no such file: $FILE"; exit 1; }
  PKG=$(dpkg-deb -f "$FILE" Package)
  REAL=$(dpkg-deb -f "$FILE" Version)
  if [ -n "$VER" ] && [ "$VER" != "$REAL" ]; then
    echo "version mismatch: you said $VER, the .deb says $REAL"
    exit 1
  fi
  cp "$FILE" "$D/"
  MSG="${MSG:-add $PKG} ($PKG $REAL)"
fi
MSG="${MSG:-update packages}"

T=$(mktemp)

# index
apt-ftparchive packages "$D" > "$D/Packages"
xz -9 -k -f "$D/Packages"

# release
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin=pkgman \
  -o APT::FTPArchive::Release::Label=pkgman \
  -o APT::FTPArchive::Release::Suite=stable \
  -o APT::FTPArchive::Release::Codename=stable \
  -o APT::FTPArchive::Release::Architectures=all \
  -o APT::FTPArchive::Release::Components=main \
  release dists/stable > "$T"
mv "$T" dists/stable/Release

# sign
gpg --yes --clearsign -o dists/stable/InRelease dists/stable/Release
gpg --yes -abs -o dists/stable/Release.gpg dists/stable/Release

# publish
git add -A
git commit -m "$MSG"
git push
