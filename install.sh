#!/bin/bash

## USAGE: bash install.sh $INSTALL_DIR
##     $ bash install.sh $INSTALL_DIR

set -eu

# OS detection
KERNEL="$(uname -s | tr '[:upper:]' '[:lower:]')"

if [ "$KERNEL" == "darwin" ]; then
  PLATFORM='osx'
elif [ "$KERNEL" == "linux" ]; then
  ARCH=$(uname -m)
  if [ "$ARCH" == "x86_64" ]; then
    PLATFORM='linux-x86_64'
  else
    PLATFORM='linux-x86'
  fi
fi

# If there is an argument then there is where GV will installed
if [ $# -eq 0 ]; then
  INSTALL_DIR=$PWD/genevalidator
else
  INSTALL_DIR="$0"
  # TODO: check if Install_dir exists and if it does then create a folder
  # inside the dir
fi

GV_URL=$(curl -s https://api.github.com/repos/wurmlab/genevalidator/releases/latest \
  | grep browser_download_url \
  | grep -i $PLATFORM \
  | cut -d '"' -f 4)

echo >&2 "==> Installing GeneValidator to:"
echo >&2 "    ${INSTALL_DIR}"

mkdir "${INSTALL_DIR}"
curl -sSL "$GV_URL" | tar zxf - -C "${INSTALL_DIR}" --strip-components 1

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
  echo >&2 'export PATH="'"${INSTALL_DIR}"'/bin:${PATH}"' >> $DOT_FILE
  echo >&2
  echo >&2 "==> Added GeneValidator to your PATH in ~/.zshrc"
  echo >&2
  echo >&2 "==> To start using GeneValidator you need to run \`source ~/.zshrc\`"
  echo >&2 "    in all your open shell windows, in rare cases you need to reopen"
  echo >&2 "    all shell windows."
  echo >&2 "    GeneValidator can then be run: \`genevalidator -h \`"
fi

echo >&2
