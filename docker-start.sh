#!/bin/bash
# Use this script to run an existing container named nft multiple times
# Remember to update the inputs - in particular the utxo file (latest script version updates it automatically)

if [ -z "$1" ]; then
	  echo "No network supplied (mainnet|testnet)"
    exit 1
  else 
    NETWORK="testnet"
fi

if [[ $NETWORK == "mainnet" ]]; then
  docker start -i cnft
else
  docker start -i cnft-test
fi
