#!/bin/bash

# DO NOT execute this script by hand. It will be copied into the docker image
# and ran during image build.

set -e
# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command failed with exit code $?"' EXIT

storePath=/tmp/nix-store/
echo "Creating temporary nix store " $storePath
mkdir -p $storePath

cd /tmp/plutus-apps/
nix-shell --run 'cd /tmp/nft/ && cabal update && cabal install && cp $(which cardano-cli) /usr/local/bin/cardano-cli 2>&1' 

binaries=("cardano-cli" "token-name" "token-policy")
for binary in $binaries; do
    echo "Finding $binary runtime dependencies"
    binPath=$(which "$binary")
    binDeps=$(ldd $binPath | tr -s ' ' | cut -d ' ' -f 3)

    echo "$binary: Copying $(echo $binDeps | wc -w | awk '{print int($1/2)}') runtime binaries to $storePath"
    for dep in $binDeps; do
        echo $dep
        depDir=$(dirname $dep)
        destPath=$storePath$depDir
        mkdir -p $destPath
        cp $dep $destPath
    done
done

binaries=("cardano-cli" "token-name" "token-policy")
for binary in $binaries; do
    echo "Finding $binary runtime dependencies"
    binPath=$(which "$binary")
    binDeps=$(ldd $binPath | tr -s ' ' | cut -d ' ' -f 1)

    echo "$binary: Copying $(echo $binDeps | wc -w | awk '{print int($1/2)}') runtime binaries to $storePath"
    echo $binDeps
    for dep in $binDeps; do
        echo "Checking: "
        echo $dep
        if [[ $dep == "/nix/store/*" ]]; then
            echo "Found nix dependencies: $dep"
            depDir=$(dirname $dep)
            destPath=$storePath$depDir
            mkdir -p $destPath
            cp $dep $destPath
        fi
    done
done