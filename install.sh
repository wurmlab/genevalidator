#!/bin/sh

## USAGE: bash install.sh $INSTALL_DIR
##     $ bash install.sh $INSTALL_DIR

set -eu

# OS detection
KERNEL="$(uname -s | tr '[:upper:]' '[:lower:]')"

if [ "$KERNEL" = "darwin" ]; then
  PLATFORM='osx'
elif [ "$KERNEL" = "linux" ]; then
  ARCH=$(uname -m)
  if [ "$ARCH" = "x86_64" ]; then
    PLATFORM='linux-x86_64'
  else
    PLATFORM='linux-x86'
  fi
fi

# If there is an argument then there is where GV will installed
if [ "$0" = 'sh' ]; then
  # I.e. when piping from curl
  INSTALL_DIR=$PWD/genevalidator
elif [[ "$0" = *install.sh ]]; then
  # I.e. when running directly
  INSTALL_DIR=$PWD/genevalidator
else
  INSTALL_DIR="$0"
fi

GV_URL=$(curl -sL https://api.github.com/repos/wurmlab/genevalidator/releases/latest \
  | grep browser_download_url \
  | grep -i $PLATFORM \
  | cut -d '"' -f 4)

# Check if the GV_URL is set (e.g. when the GITHUB API does not return what we expect)
if [ -z "$GV_URL" ]; then
  echo >&2 '==> Unable find the link to the latest version of the standalone GeneValidator Package.'
  echo >&2 '    Please download the latest version of GeneValidator from the following link:'
  echo >&2 '        https://github.com/wurmlab/genevalidator/releases/latest'
  exit 1
fi

echo >&2 "==> Installing GeneValidator to:"
echo >&2 "    ${INSTALL_DIR}"
echo >&2

mkdir "${INSTALL_DIR}"
curl -SL "$GV_URL" | tar zxf - -C "${INSTALL_DIR}" --strip-components 1

echo >&2
echo >&2 "==> GeneValidator successfully installed."

### Check which SHELL and then test different profile files
case $SHELL in
*/zsh)
  # assume Zsh
  if test -e "${HOME}/.zshrc"; then
    DOT_FILE=${HOME}/.zshrc
  elif test -e "${HOME}/.zprofile"; then
    DOT_FILE=${HOME}/.zprofile
  elif test -e "${HOME}/.profile"; then
    DOT_FILE=${HOME}/.profile
  fi
  ;;
*/bash)
  # assume Bash
  if test -e "${HOME}/.bashrc"; then
    DOT_FILE=${HOME}/.bashrc
  elif test -e "${HOME}/.bash_profile"; then
    DOT_FILE=${HOME}/.bash_profile
  elif test -e "${HOME}/.profile"; then
    DOT_FILE=${HOME}/.profile
  fi
  ;;
*)
  if test -e "${HOME}/.profile"; then
    DOT_FILE=${HOME}/.profile
  fi
esac


if [ -z ${DOT_FILE+x} ]; then
  # DOT File hasn't been set.
  echo >&2
  echo >&2 '==> No profile files were found.'
  echo >&2 '    Please create one and add the following line to that file:'
  echo >&2
  echo >&2 '    export PATH="'"${INSTALL_DIR}"'/bin:${PATH}"'
else
  echo >&2 'export PATH="'"${INSTALL_DIR}"'/bin:${PATH}"' >> "${DOT_FILE}"
  echo >&2
  echo >&2 "==> Added GeneValidator to your PATH in ${DOT_FILE}"
  echo >&2
  echo >&2 "==> Run \`genevalidator -h\` in a new window to get started."
fi

echo >&2
