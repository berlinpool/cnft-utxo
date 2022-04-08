# NFT Maker

The following repository allows to create Cardano NFTs on the Cardano Blockchain via a docker image that sets up all the required dependencies. Containers of the image run as executable by providing specific input files.

## Requirements

- running a fully synchronized cardano node for the respective network (mainnet|testnet)
- docker

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

## Debugging

The mint script outputs all its inputs. That should be primary help for finding errors. In addition any error coming from submitting transaction via the cardano-cli binary will also be printed to the console.