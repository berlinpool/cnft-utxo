#!/bin/bash

oref=$(cat $1)
amt=1
tn=$(cat $2)
addrFile=$3
skeyFile=$4

echo "oref: $oref"
echo "amt: $amt"
echo "tn: $tn"
echo "address file: $addrFile"
echo "signing key file: $skeyFile"
echo 

mkdir -p $NETWORK
ppFile=protocol-parameters.json

policyFile=token.plutus
token-policy $policyFile $oref $tn

tp=$(cat $policyFile)
unsignedFile=${NETWORK}/tx.unsigned
signedFile=${NETWORK}/tx.signed
pid=$(cardano-cli transaction policyid --script-file $policyFile)
tnHex=$(token-name $tn)
addr=$(cat $addrFile)
v="$amt $pid.$tnHex"
in_metadataFile=${INPUTS_DIR}/metadata.json
out_metadataFile=${INPUTS_DIR}/metadata_out.json

echo "currency symbol: $pid"
echo "token name (hex): $tnHex"
echo "minted value: $v"
echo "address: $addr"

if [[ "$NETWORK" == "mainnet" ]]; then
MAGIC=--mainnet
else
MAGIC=--testnet-magic 1097911063
fi
cardano-cli query protocol-parameters $MAGIC --out-file protocol-parameters.json
pp=$(cat protocol-parameters.json | jq .)
echo "params: $pp"
echo $(ls -la /var/cardano/inputs)
echo $(echo $in_metadataFile)

if [ ! -f in_metadataFile ]; then
    echo "metadata: none"
    cardano-cli transaction build \
        $MAGIC \
        --tx-in $oref \
        --tx-in-collateral $oref \
        --tx-out "$addr + 1500000 lovelace + $v" \
        --mint "$v" \
        --mint-script-file $policyFile \
        --mint-redeemer-file /usr/local/etc/unit.json \
        --change-address $addr \
        --protocol-params-file protocol-parameters.json \
        --out-file $unsignedFile
    else
    sh ./create-metadata.sh $pid $in_metadataFile $out_metadataFile
    echo "metadata: $(cat $mdata | jq .)"

    cardano-cli transaction build \
        $MAGIC \
        --tx-in $oref \
        --tx-in-collateral $oref \
        --tx-out "$addr + 1500000 lovelace + $v" \
        --mint "$v" \
        --mint-script-file $policyFile \
        --mint-redeemer-file ${INPUTS_DIR}/unit.json \
        --change-address $addr \
        --metadata-json-file $out_metadataFile \
        --protocol-params-file $ppFile \
        --out-file $unsignedFile
fi

cardano-cli transaction sign \
    --tx-body-file $unsignedFile \
    --signing-key-file $skeyFile \
    $MAGIC \
    --out-file $signedFile

cardano-cli transaction submit \
    $MAGIC \
    --tx-file $signedFile
