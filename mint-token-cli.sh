#!/bin/bash

oref=$1
amt=1
tn=$2
addrFile=$3
skeyFile=$4

echo "oref: $oref"
echo "amt: $amt"
echo "tn: $tn"
echo "address file: $addrFile"
echo "signing key file: $skeyFile"
echo 

ppFile=${NETWORK}/protocol-parameters.json

policyFile=${NETWORK}/token.plutus
token-policy $policyFile $oref $tn

unsignedFile=${NETWORK}/tx.unsigned
signedFile=${NETWORK}/tx.signed
pid=$(cardano-cli transaction policyid --script-file $policyFile)
tnHex=$(token-name $tn)
addr=$(cat $addrFile)
v="$amt $pid.$tnHex"

echo "currency symbol: $pid"
echo "token name (hex): $tnHex"
echo "minted value: $v"
echo "address: $addr"

cardano-cli transaction build \
    $MAGIC \
    --tx-in $oref \
    --tx-in-collateral $oref \
    --tx-out "$addr + 1500000 lovelace + $v" \
    --mint "$v" \
    --mint-script-file $policyFile \
    --mint-redeemer-file testnet/unit.json \
    --change-address $addr \
    --protocol-params-file $ppFile \
    --out-file $unsignedFile \

cardano-cli transaction sign \
    --tx-body-file $unsignedFile \
    --signing-key-file $skeyFile \
    $MAGIC \
    --out-file $signedFile

cardano-cli transaction submit \
    $MAGIC \
    --tx-file $signedFile
