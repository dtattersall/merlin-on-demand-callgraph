#!/usr/bin/env bash

# set -x  # Uncomment for testing

CURRENT_DIR=$(pwd)

# Associative array of packages and their respective main files, using the benchmark directory as base for the relative path
declare -A PACKAGES=(
  ["makeappicon"]="lib/index.js" # Rollup works
  ["spotify-terminal"]="src/control.js"
  ["ragan-module"]="index.js"
  ["npm-git-snapshot"]="index.js"
  ["nodetree"]="index.js" # Rollup works
  ["jwtnoneify"]="src/noneify.js"
  ["foxx-framework"]="bin/foxxy"
  ["npmgenerate"]="bin/ngen.js"
  ["smrti"]="app.js" # Rollup works
  ["openbadges-issuer"]="cli.js"
  ["mvvc"]="bin/mvvc.js"
)

usage() {
    echo "script usage: $(basename $0) -j path-to-jam" >&2
    echo ""
    echo "Note: Requires Node version 18+"
    echo ""
}

#j: PATH-TO-JAM (ISSTA2021 CG tool)
while getopts 'j:' OPTION; do
  case "$OPTION" in
    j) PATH_TO_JAM="$OPTARG";;
    ?) usage
       exit 1;;
  esac
done

if [ -z "$PATH_TO_JAM" ] ; then
  echo "Error: No -j option provided"
  usage
  exit 1
fi

NODE_VERSION_STR=$(node --version)
NODE_VERSION=$((${NODE_VERSION_STR:1:2}))
if [[ $NODE_VERSION < 18 ]]; then
   echo "Node version ${NODE_VERSION_STR} (interpreted as ${NODE_VERSION}) is less than required Node version (18+)"
   usage
   exit 1
fi

# top-level install
echo "Installing package.json dependencies via npm"
npm install --prefix eval-targets &>/dev/null

if [ ! -d "eval-targets/node_modules" ] ; then
  echo "Could not successfully install packages. Is npm properly installed?" && exit 1
fi

# install rollup
echo "Installing rollup for bundling of benchmark modules"
npm install -g rollup &>/dev/null
echo "Installing rollup plugins"
npm install -g @rollup/plugin-node-resolve &>/dev/null
npm install -g @rollup/plugin-json &>/dev/null
npm install -g @rollup/plugin-commonjs &>/dev/null
npm install -g rollup-plugin-strip-shebang &>/dev/null


# package-level install
for PACKAGE in "${!PACKAGES[@]}"
do
  echo "Installing ${PACKAGE} via npm"
  npm install --prefix eval-targets "${PACKAGE}" &>/dev/null
  echo "bundling ${PACKAGE} with rollup"
  cd "eval-targets/node_modules/${PACKAGE}"
  # outputs a bundled file to eval-targets/node_modules/${PACKAGE}/bundle.js
  rollup "${PACKAGES[$PACKAGE]}" --file bundle.js --format cjs -p rollup-plugin-strip-shebang -p node-resolve -p commonjs -p json
  cd "${CURRENT_DIR}"
done

# Fix path errors in Jam's static-configuration.ts file
echo "Fixing Jam path errors"
PROJ_HOME_OLD="isInTest ? '../' : '../../'"
PROJ_HOME_NEW="'../'"
NODE_PROF_OLD="'src', 'node-prof-analyses'"
NODE_PROF_NEW="'dist', 'node-prof-analyses'"
sed -i '' "s+$NODE_PROF_OLD+$NODE_PROF_NEW+g" "${PATH_TO_JAM}"/src/static-configuration.ts
sed -i '' "s+$PROJ_HOME_OLD+$PROJ_HOME_NEW+g" "${PATH_TO_JAM}"/src/static-configuration.ts
cd "$PATH_TO_JAM"
echo "re-compiling Jam"
npm run build

echo "Installing node-based evaluation tool"
npm install --prefix "${CURRENT_DIR}" &>/dev/null

cd "$CURRENT_DIR"
echo "Finished setup"
