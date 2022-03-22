#!/bin/bash
# Replace relay1-ipc with container volume for node socket
# Alternatively, run cardano-node container, let it sync.
# docker run -it --rm \
#  	-v node-config:/opt/cardano/config \
#  	-v node-data:/opt/cardano/data \
#  	-v node-ipc:/opt/cardano/ipc \
#	nessusio/cardano-node
docker run -it --name nft --rm \
	-v relay1-ipc:/opt/cardano/ipc \
	-v $(pwd)/inputs:/var/cardano/inputs \
	psg/nft:latest
