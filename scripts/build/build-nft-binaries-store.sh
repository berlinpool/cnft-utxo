#!/bin/bash

# DO NOT execute this script by hand. It will be copied into the docker image
# and ran during image build.

set -e
# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command failed with exit code $?"' EXIT

storePath=/tmp/nix-store/
#echo "Creating temporary nix store " $storePath
mkdir -p $storePath

declare -a binaries=("token-name" "token-policy" "cardano-cli")
for binary in "${binaries[@]}"
do
    echo "Finding $binary runtime dependencies:"
    binPath="$(which $binary)"
    # filter for all dynamically linked /nix/store dependencies of binary
    binDeps=$(ldd $binPath | cut -d ' ' -f 1,3 | xargs | tr ' ' '\n' | grep '^/nix/store/')
    echo "$binary: Copying $(echo $binDeps | wc -w) runtime binaries to $storePath"
    for dep in $binDeps
    do
        echo ""
        depPath=$(dirname $dep)
        mkdir -p $storePath$depPath
        echo "Copying $dep to $storePath$depPath"
        cp $dep "$storePath$depPath/$(basename $dep)" || true
    done
done

exit $?