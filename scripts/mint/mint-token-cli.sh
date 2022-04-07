#!/bin/bash

set -e
# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command failed with exit code $?"' EXIT

# Set environment variables correctly for network & cardano-cli
if [[ "$NETWORK" == "mainnet" ]]; then
    MAGIC=--mainnet
    NETWORK=mainnet
else
    MAGIC="--testnet-magic 1097911063"
    NETWORK=testnet
fi

echo "Network: $NETWORK"

# Validate UTxO file exists
utxoFile=${INPUTS_DIR}/${NETWORK}/$1
if [[ -f "$utxoFile" ]]; then
    oref=$(cat $utxoFile)
else
    echo "No UTxO file found: $utxoFile"
    exit 1
fi

# Validate tn (token name) file exists
tnFile=${INPUTS_DIR}/${NETWORK}/$2
if [ ! -f "$tnFile" ]; then
    echo "No token name file found: $tnFile"
    exit 1
else
    tn=$(cat $tnFile)
fi

# Validate Address file exists
addrFile=${INPUTS_DIR}/${NETWORK}/$3
if [ ! -f "$addrFile" ]; then
    echo "No address file found: $addrFile"
    exit 1
fi

# Validate signing file exists
skeyFile=${INPUTS_DIR}/${NETWORK}/$4
if [ ! -f "$skeyFile" ]; then
    echo "No signing file found: $skeyFile"
    exit 1
fi

amt=1
echo "Found inputs:"
echo "utxo: $oref"
echo "token name: $tn"
echo "address file: $addrFile"

# Setup directory to backup policy scripts inside inputs volume
txsFolder=${INPUTS_DIR}/${NETWORK}/txs
mkdir -p $txsFolder

policyFolder=${INPUTS_DIR}/${NETWORK}/policies
mkdir -p $policyFolder
ppFile=/tmp/protocol-parameters.json

policyFile=token.plutus
# Generate policy script
token-policy $policyFile $oref $tn

unsignedFile=/tmp/tx.unsigned
signedFile=/tmp/tx.signed
# Generate policyId - script hash/ currency symbol
pid=$(cardano-cli transaction policyid --script-file $policyFile)
tnHex=$(token-name $tn)
cp ./${policyFile} ${policyFolder}/${pid}.${tnHex}.plutus
echo "Generated policy file ${policyFolder}/${pid}.${tnHex}.plutus"
addr=$(cat $addrFile)
v="$amt $pid.$tnHex"
in_metadataFile=${INPUTS_DIR}/metadata.json
out_metadataFile=/tmp/metadata_out.json

# Query for current protocol parameters in respect to network
cardano-cli query protocol-parameters $MAGIC --out-file $ppFile

if [ -f "$in_metadataFile" ]; then
    sh ./create-metadata.sh $pid $tn $in_metadataFile $out_metadataFile
    cardano-cli transaction build \
        $MAGIC \
        --tx-in $oref \
        --tx-in-collateral $oref \
        --tx-out "$addr + 1500000 lovelace + $v" \
        --mint "$v" \
        --mint-script-file $policyFile \
        --mint-redeemer-file /usr/local/etc/unit.json \
        --change-address $addr \
        --metadata-json-file $out_metadataFile \
        --protocol-params-file $ppFile \
        --out-file $unsignedFile
else
    cardano-cli transaction build \
        $MAGIC \
        --tx-in $oref \
        --tx-in-collateral $oref \
        --tx-out "$addr + 1500000 lovelace + $v" \
        --mint "$v" \
        --mint-script-file $policyFile \
        --mint-redeemer-file /usr/local/etc/unit.json \
        --change-address $addr \
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

tx=$(cardano-cli transaction view --tx-file $signedFile)
txid=$(cardano-cli transaction txid --tx-file $signedFile)

echo $tx > ${txsFolder}/${txid}.tx
echo "Submitted transaction & saved to file $txsFolder/$txid.tx"
./clean-up.sh

echo "Find out more on-chain: "
if [[ "$NETWORK" == "mainnet" ]]; then
    echo "Transaction:  https://cardanoscan.io/transaction/$txid"
    echo "Address:      https://cardanoscan.io/address/$addr"
    echo "TokenPolicy:  https://cardanoscan.io/tokenPolicy/$pid"
else
    echo "Transaction:  https://testnet.cardanoscan.io/transaction/$txid"
    echo "Address:      https://testnet.cardanoscan.io/address/$addr"
    echo "TokenPolicy:  https://testnet.cardanoscan.io/tokenPolicy/$pid"
fi

echo "Updated UTxO file ($txid#0)"
echo "$txid#0" > $utxoFile
echo "Successfully submitted transaction."