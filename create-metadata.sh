#!/bin/bash

if [ -z "$1" ]
  then
    echo "No policy id supplied"
    exit 1
  else 
    policyid=$1
fi

if [ -z "$2" ]
  then
    echo "No metadata json file supplied"
    exit 1
  else
    metadataFile=$2
fi

METADATA="{\"721\":{\"$(echo $policyid)\":{\"$(echo $TOKENNAME)\":$(cat $metadataFile)}}}"

if [ -z "$3" ]
  then
    echo $METADATA
  else
    echo $METADATA > $3
    echo "Wrote output to $3"
fi
