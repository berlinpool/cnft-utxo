#!/bin/bash

if [ -z "$1" ]; then
    echo "No image version supplied (default: 1.0.0)"
	VERSION=1.0.0
  else 
    VERSION=$1
fi

docker build --label berlinpool/cnft-utxo -t berlinpool/cnft-utxo:$VERSION -t berlinpool/cnft-utxo:latest .
