#!/bin/bash
# Set environment variables correctly for network & cardano-cli
if [[ "$NETWORK" == "mainnet" ]]; then
    MAGIC=--mainnet
    NETWORK=mainnet
else
    MAGIC="--testnet-magic 1097911063"
    NETWORK=testnet
fi

echo "Network: $NETWORK"
utxoFile=${INPUTS_DIR}/${NETWORK}/$1
tnFile=${INPUTS_DIR}/${NETWORK}/$2
oref=$(cat $utxoFile)
amt=1
tn=$(cat $tnFile)
addrFile=${INPUTS_DIR}/${NETWORK}/$3
skeyFile=${INPUTS_DIR}/${NETWORK}/$4

echo "oref: $oref"
echo "amt: $amt"
echo "tn: $tn"
echo "address file: $addrFile"
echo "signing key file: $skeyFile"


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
cp ./${policyFile} ${policyFolder}/${pid}.${tn}.plutus
tnHex=$(token-name $tn)
addr=$(cat $addrFile)
v="$amt $pid.$tnHex"
in_metadataFile=${INPUTS_DIR}/metadata.json
out_metadataFile=/tmp/metadata_out.json

echo "currency symbol: $pid"
echo "token name (hex): $tnHex"
echo "minted value: $v"
echo "address: $addr"

# Query for current protocol parameters in respect to network
cardano-cli query protocol-parameters $MAGIC --out-file $ppFile

if [ -f "$in_metadataFile" ]; then
    sh ./create-metadata.sh $pid $tn $in_metadataFile $out_metadataFile
    echo "metadata: $(cat $out_metadataFile | jq .)"

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
echo "Wrote transaction to file $txsFolder/$txid.tx"
sh ./clean-up.sh

echo "Visit: "
if [[ "$NETWORK" == "mainnet" ]]; then
    echo "Transaction:  https://cardanoscan.io/transaction/$txid"
    echo "Address:      https://cardanoscan.io/address/$addr"
    echo "TokenPolicy:  https://cardanoscan.io/tokenPolicy/$pid"
else
    echo "Transaction:  https://testnet.cardanoscan.io/transaction/$txid"
    echo "Address:      https://testnet.cardanoscan.io/address/$addr"
    echo "TokenPolicy:  https://testnet.cardanoscan.io/tokenPolicy/$pid"
fi

echo "Overriding utxo file with new txHash#txId"
echo "$txid#0" > $utxoFile