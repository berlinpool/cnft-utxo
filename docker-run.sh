#!/bin/bash
# Replace relay1-ipc with container volume for node socket
# Alternatively, run cardano-node container, let it sync.
# docker run -it --rm \
#  	-v node-config:/opt/cardano/config \
#  	-v node-data:/opt/cardano/data \
#  	-v node-ipc:/opt/cardano/ipc \
#	nessusio/cardano-node

if [ -z "$1" ]; then
		echo "No network supplied (mainnet|testnet)"
    exit 1
  else 
    NETWORK=$1
fi

if [ -z "$2" ]; then
		echo "No metadata option defined for using CIP25 standard template (true|false) -> defaulting to false"
    USE_CIP25=false
  else 
    USE_CIP25="$2"
fi

if [[ $NETWORK == "mainnet" ]]; then
	docker run -it --name cnft --rm \
		-v relay1-ipc:/opt/cardano/ipc \
		-v $(pwd)/inputs:/var/cardano/inputs \
		-e NETWORK=$NETWORK \
		-e USE_CIP25=$USE_CIP25 \
		berlinpool/cnft-utxo:latest
else
	docker run -it --name cnft-test --rm \
		-v test-relay-ipc:/opt/cardano/ipc \
		-v $(pwd)/inputs:/var/cardano/inputs \
		-e NETWORK=$NETWORK \
		-e USE_CIP25=$USE_CIP25 \
		berlinpool/cnft-utxo:latest
fi

