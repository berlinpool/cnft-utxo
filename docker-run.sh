#!/bin/bash

docker run -it --name nft \
	-v relay1-ipc:/opt/cardano/ipc \
	-v $(pwd)/inputs:/var/cardano/inputs \
	psg/nft:latest
