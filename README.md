# UTxO based CNFT Maker

The following repository allows to create ***true*** Cardano NFTs on the Cardano Blockchain via a docker image that sets up all the required dependencies. 
Containers of the image run as executable by providing specific input files and require access to a fully synced Cardano node ipc.

## Requirements

- [docker](https://docs.docker.com/engine/install/)
- run a fully synchronized [cardano node](#set-up-a-cardano-node) for the respective network (mainnet|testnet)
- [input files](#input-files)

### Set up a Cardano Node

We recommend either using the official [IO Cardano Node](https://hub.docker.com/r/inputoutput/cardano-node) docker image or an enhanced [community image](https://hub.docker.com/r/nessusio/cardano-node) like for instance by [nessusio](https://hub.docker.com/u/nessusio) for simplified usage.

Example:

```
docker run --detach \
    --name=node \
    -p 3001:3001 \
    -e CARDANO_UPDATE_TOPOLOGY=true \
    -e CARDANO_NETWORK=mainnet|testnet \
    -v node-config:/opt/cardano/config \
    -v node-data:/opt/cardano/data \
    -v node-ipc:/opt/cardano/ipc \
    nessusio/cardano-node run
```

Check the node's sync status with:
`docker exec -it node gLiveView`

### Input Files

Default input files paths can be changed by overriding `INPUTS_DIR` environment variable or by pointing your volume to a different directory:

- `payment.addr`
- `payment.skey`
- `tokenname`
- `utxo`
- `metadata.json` *(optional)*

## Docker Helper Scripts
There are three helper scripts that can be used to build a custom image, create a container or rerun/ reuse an existing container.

### Build Docker Image
Building the docker image the first time takes a while, because the plutus dependencies are build and installed. Also make sure you change the
[Dockerfile](Dockerfile) to not checkout the repo but copy your local repository when building a custom image if you have pending changes.

Run `./docker-build.sh [<version|default:1.0.0>]` or adjust parameters.
You can provide a version number to the build script. The default version is `1.0.0`

### Create Docker Container

Either make use of the helper script `docker-run.sh` or inspect and adjust the docker command of that script to create a new container.

Use `./docker-run.sh (mainnet | testnet) [true | default: false]` to create
a new container for a target network and optionally define whether to make use of the [CIP-0025](https://github.com/cardano-foundation/CIPs/blob/master/CIP-0025/README.md#structure) Metadata Standard or not.

If ran with option set to `true` the passed in `metadata.json` file will be encapsulated into a template with the respective policy id.
For details check out [create-metadata.sh](scripts/mint/create-metadata.sh#L29)

#### Manual Docker Container Creation

```
docker run -it \
    --name cnft \
    --rm \
    -v node-ipc:/opt/cardano/ipc \
    -v $(pwd)/inputs:/var/cardano/inputs \
    -e NETWORK=$NETWORK \
    -e USE_CIP25=(true|default: false)
    berlinpool/cnft-utxo:latest
```

### Start Docker Container
Use `./docker-start.sh (DOCKER ID| NAME)` to rerun an existing container and mint over again.

## Metadata
By default the provided metadata file is copied one-to-one and attached to the transaction. There is no formatting/ templating etc.

### CIP-0025 Stanard Image CNFTs
For image NFTs there is an option that is required to be passed when running this container in order to take advantage of the [NFT standard template](https://github.com/cardano-foundation/CIPs/blob/master/CIP-0025/README.md#structure).

If you use the helper `docker-run.sh` script you can just pass a second boolean argument to whether you want to use the CIP25 template or not.
Alterntively, you can also set the environment variable USE_CIP25 to either `true` or `false`.
