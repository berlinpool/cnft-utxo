#
# Multi stage image build:
# (1) BUILD stage:
#	- install nix
#	- set up IOHK binary cache
#	- build plutus binaries using nix-shell
#	- build nft binaries using cabal
#	- copy cardano-cli binary and nft binaries to /root/.cabal/bin
# (2) RUN stage:
#	- set up environment variables with default values
#	- copy binaries from build stage /root/.cabal/bin to /usr/local/bin
#	- copy mint cli script to /usr/local/etc
#	- update PATH to include binaries
#	- fetch current protocol parameters via CLI for testnet & mainnet to reduce script runtime
#  	- set CMD and ENTRYPOINT to run docker container as executable with respective
#	  default values provided in docker volume

#                                                                              #
# --------------------------- BUILD (plutus) --------------------------------- #
#                                                                              #

FROM ubuntu:20.04 as build

# GIT COMMIT id which must match with plutus-apps dependency in the cabal.project file of nft repo
ARG COMMIT_ID=6e3f6a59d64f6d4cd9d38bf263972adaf4f7b244

RUN apt-get update && apt-get install --no-install-recommends -y locales git pkg-config curl xz-utils vim ca-certificates && apt-get clean && rm -rf /var/lib/apt/lists/* \
      && mkdir -m 0755 /nix && groupadd -r nixbld && chown root /nix \
      && for n in $(seq 1 10); do useradd -c "Nix build user $n" -d /var/empty -g nixbld -G nixbld -M -N -r -s "$(command -v nologin)" "nixbld$n"; done

# Install nix
RUN curl -L https://nixos.org/nix/install | sh

# Setup IOHK binary cache for building plutus dependencies
RUN mkdir -p /etc/nix &&\
    touch /etc/nix/nix.conf &&\
    echo "substituters = https://cache.nixos.org https://hydra.iohk.io" >> /etc/nix/nix.conf &&\
    echo "trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" >> /etc/nix/nix.conf

RUN mkdir -p /tmp/nft
# Copy over nft repo to build binaries 
COPY . /tmp/nft/

RUN git clone https://github.com/input-output-hk/plutus-apps.git /tmp/plutus-apps/
WORKDIR /tmp/plutus-apps/
# Git commit id must match cabal.project tag
RUN git checkout $COMMIT_ID
# Set PATH to include .nix_profile & cabal/bin path to run nix-shell
ENV PATH="$PATH:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/root/.cabal/bin"
# Update & Build binaries required for plutus & nft repository
RUN nix-shell --run "cd /tmp/nft/ && cabal update && cabal install"
# Copy cardano-cli binary to .cabal/bin for copying later during RUN phase
RUN cp /nix/store/*exe-cardano-cli-*/bin/cardano-cli /root/.cabal/bin/cardano-cli

#                                                                              #
# ---------------------------------- RUN ------------------------------------- #
#                                                                              #

# Prerequisites:
#
# Provide the following input files unless ENV variables are overriden:
# ./inputs/utxo
# ./inputs/tokenname
# ./inputs/payment.addr
# ./inputs/payment.skey
#
# Have fully synced cardano node ready whose ipc socket file can be exposed via docker volume!
# We presume node-ipc is an existing volume which contains node.socket
#
# Create container by running:
# docker run -it \
#   --name nft \
#   -v node-ipc:/opt/cardano/ipc \
#   -v $(pwd)/inputs:/var/cardano/inputs \
#   [
#   -e UTXO=<path/to/utxo_file> | 
#   -e TOKENNAME=<path/to/tokenname_file> |
#   -e ADDR_FILE=<path/to/addr_file> |
#   -e SKEY_FILE=<path/to/skey_file> |
#   ]
#   psg/nft:latest
#   [ <txid#idx> <tokenname> /path/to/addr_file /path/to/skey_file ]

FROM ubuntu:20.04

ARG SCRIPT_PATH=/usr/local/etc
ARG MAGIC=--mainnet

# Default environment variables
ENV NETWORK=mainnet
ENV MAGIC=$MAGIC
ENV INPUTS_DIR=/var/cardano
ENV CARDANO_NODE_SOCKET_PATH=/opt/cardano/ipc/node.socket

# Input files:
ENV UTXO=${INPUTS_DIR}/utxo
ENV TOKENNAME=${INPUTS_DIR}/tokenname
ENV ADDR_FILE=${INPUTS_DIR}/payment.addr
ENV SKEY_FILE=${INPUTS_DIR}/payment.skey

# Copy necessary files 
COPY ./mint-token-cli.sh ${SCRIPT_PATH}/mint-token-cli.sh
COPY ./testnet/unit.json ${SCRIPT_PATH}/testnet/unit.json
# Copy necessary binaries
COPY --from=build /root/.cabal/bin/* /usr/local/bin/

# Update PATH to include newly copied binaries
ENV PATH="$PATH:/usr/local/bin"

# Fetch protocol parameters in case not existing
RUN cardano-cli query protocol-parameters --mainnet --out-file ${SCRIPT_PATH}/mainnet/protocol-parameters.json
RUN cardano-cli query protocol-parameters --testnet-magic 1097911063 --out-file ${SCRIPT_PATH}/testnet/protocol-parameters.json

ENTRYPOINT [ "${SCRIPT_PATH}/mint-token-cli.sh" ]
CMD [ $(cat $UTXO), $(cat $TOKENNAME), $ADDR_FILE, $SKEY_FILE ]

