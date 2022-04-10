r
ea# UTxO based CNFT Maker

The following repository allows to create *true* Cardano NFTs on the Cardano Blockchain via a docker image that sets up all the required dependencies. 
Containers of the image run as executable by providing specific input files and require access to a fully synced Cardano node ipc.

## Requirements

- running a fully synchronized cardano node for the respective network (mainnet|testnet)
- docker
- input files

### Required Input Files

Default input files paths can be changed
by overriding INPUTS_DIR environment variable:
- ./inputs/metadata.json (optional)
- ./inputs/*network*/payment.addr
- ./inputs/*network*/payment.skey
- ./inputs/*network*/tokenname
- ./inputs/*network*/utxo

## Usage

Checkout repository and make sure you have docker installed on your machine.

Run `./docker-build.sh`

*You can provide a version number to the build script. The default is 1.0.0*

The first time building this image takes a while, because the plutus dependencies are build and installed.

Before running a container you *must* have a sycned cardano node.
If you want to use a comunity docker image for running a node, I recommend `nessusio/cardano-node`. It comes with great additional tools for observing the current state of a running node.

```
docker run --detach \
    --name=relay \
    -p 3001:3001 \
    -e CARDANO_UPDATE_TOPOLOGY=true \
    -e CARDANO_NETWORK=mainnet|testnet \
    -v node-config:/opt/cardano/config \
    -v node-data:/opt/cardano/data \
    -v node-ipc:/opt/cardano/ipc \
    nessusio/cardano-node run
```

Check sync status with:
`docker exec -it relay gLiveView`

Checkout their [docker hub](https://hub.docker.com/r/nessusio/cardano-node) for more info.

*The synchronization of a node usually takes a couple hours*

Once the image is built and the node is in sync, continue by preparing the inputs for the container.

By default - using the *docker-run.sh* script a docker volume is 
created for the required input files. The default location is 
**./inputs**.

Update the following files respectively to your needs:

### Input Files

- ./inputs/metadata.json
- ./inputs/*network*/payment.addr
- ./inputs/*network*/payment.vkey
- ./inputs/*network*/payment.skey
- ./inputs/*network*/tokenname
- ./inputs/*network*/utxo

After creating the files for the respective network,

Before running docker-run script, adjust the name of the node.
run `./docker-run.sh <network>` to use the default setup or alternatively, provide a different volume path of your choice.

This runs the mint script which will eventually output links
to the respective transaction that you can open to monitor
when the token was successfully minted onchain.

## Metadata
By default the provided metadata file is copied one-to-one and attached to the transaction.
There is no formatting/ templating etc.

### Image CNFTs
For image NFTs there is an option that is required to be passed when running this container in order
to take advantage of the [NFT standard template](https://github.com/cardano-foundation/CIPs/blob/master/CIP-0025/README.md#structure).

If you use the helper `docker-run.sh` script you can just pass a second boolean argument to whether you want to use the CIP25 template or not.
Alterntively, you can also set the environment variable USE_CIP25 to either `true` or `false`.

## Debugging

The mint script outputs all its inputs. That should be primary help for finding errors. In addition any error coming from submitting transaction via the cardano-cli binary will also be printed to the console.


cardano-cli transaction build --alonzo-era --mainnet \
--tx-in 050b20cd859c31aeb491ca9787e4df7312a3cddd415877fa06169d63573e8333#1 \
--tx-in 258fcb7f6868e99c4c109d90deeb08b66e2b0b61184c139566b0f0cb0384833b#1 \
--tx-in 5792ad4bb494ee8fab17496bb734a2418ea417474ca13cb7e965edd4f9ccfafc#0 \
--tx-in 5792ad4bb494ee8fab17496bb734a2418ea417474ca13cb7e965edd4f9ccfafc#1 \
--tx-in 69d145f246f0c4f3b71af10af5f010c1ebd27dc9f16416ccdeafcaa58b91baa0#1 \
--tx-in 6d031153b7780181b53ffb67c26a623e4060ccef44c3725d2b39bdebdb50eaa9#1 \
--tx-in 949099247ce7f9e6dadd3022cbd8867bf11b00c2d7079ccf69038df1db821c7c#1 \
--tx-out "$(cat dest.addr) + 17674748 lovelace" \
--change-address $(cat dest.addr) \
--protocol-params-file protocol-parameters.json \
--out-file tx.raw