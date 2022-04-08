#!/bin/bash
# Use this script to run an existing container named nft multiple times
# Remember to update the inputs - in particular the utxo file (latest script version updates it automatically)

if [ -z "$1" ]; then
    echo "No network supplied (mainnet|testnet)"
    exit 1
  else 
    NETWORK="testnet"
fi

if [ -z "$2" ]; then
    echo "No metadata option defined for using CIP25 standard template (true|false) -> defaulting to false"
    USE_CIP25="false"
  else 
    USE_CIP25="$2"
fi

if [[ $NETWORK == "mainnet" ]]; then
    docker start -i cnft -e USE_CIP25=$USE_CIP25
  else
    docker start -i cnft-test -e USE_CIP25=$USE_CIP25
fi
