#!/bin/bash
#
# Use this script to run an existing container named nft multiple times

if [ -z "$1" ]; then
    echo "No container name/ id supplied"
    exit 1
fi

docker start -i $1
