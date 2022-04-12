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
    echo "No tokenname supplied"
    exit 1
  else 
    tokenname=$2
fi

if [ -z "$3" ]
  then
    echo "No metadata json file supplied"
    exit 1
  else
    metadataFile=$3
fi

if [[ "$USE_CIP25" == "true" ]]; then
  # use CIP25 metadata standard
  METADATA="{\"721\":{\"$(echo $policyid)\":{\"$(echo $tokenname)\":$(cat $metadataFile)}}}"
else
  METADATA="$(cat $metadataFile)"
fi

if [ -z "$4" ]
  then
    echo $METADATA
  else
    echo $METADATA > $4
    echo "Wrote output to $4"
fi
