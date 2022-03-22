#
# Image build:
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

FROM ubuntu:20.04

# GIT COMMIT id which must match with plutus-apps dependency in the cabal.project file of nft repo
ARG COMMIT_ID=6e3f6a59d64f6d4cd9d38bf263972adaf4f7b244

RUN apt-get update && apt-get install --no-install-recommends -y locales git pkg-config curl xz-utils vim ca-certificates jq && apt-get clean && rm -rf /var/lib/apt/lists/* \
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
RUN git clone https://github.com/william-wolff-io/nft-maker.git /tmp/nft/
RUN git clone https://github.com/input-output-hk/plutus-apps.git /tmp/plutus-apps/
WORKDIR /tmp/plutus-apps/
# Git commit id must match cabal.project tag
RUN git checkout $COMMIT_ID
# Set PATH to include .nix_profile & cabal/bin path to run nix-shell
ENV PATH="$PATH:/nix/var/nix/profiles/default/bin:/usr/local/bin:/bin:/root/.cabal/bin"
# Update & Build binaries required for plutus & nft repository
RUN nix-shell --run 'cd /tmp/nft/ && cabal update && cabal install && cp $(which cardano-cli) /usr/local/bin/cardano-cli'
WORKDIR /usr/local/etc

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
# ./inputs/metadata.json (optional)
#
# Have fully synced cardano node ready whose ipc socket file can be exposed via docker volume!
# We presume node-ipc is an existing volume which contains node.socket
#
# Either run docker-run.sh or the following command:
# docker run --name nft \
#   -v node-ipc:/opt/cardano/ipc \
#   -v $(pwd)/inputs:/var/cardano/inputs \
#   psg/nft:latest

# Copy necessary files 
RUN cp /tmp/nft/mint-token-cli.sh /usr/local/etc/mint-token-cli.sh
RUN cp /tmp/nft/create-metadata.sh /usr/local/etc/create-metadata.sh
RUN cp /tmp/nft/testnet/unit.json /usr/local/etc/unit.json
# Remove cloned repos for binary build
RUN rm -rf /tmp/nft /tmp/plutus-apps

ENTRYPOINT [ "/usr/local/etc/mint-token-cli.sh" ]
CMD [ "/var/cardano/inputs/utxo", "/var/cardano/inputs/tokenname", "/var/cardano/inputs/payment.addr", "/var/cardano/inputs/payment.skey" ]

ENV SCRIPT_PATH=/usr/local/etc
ENV INPUTS_DIR=/var/cardano/inputs
ENV NETWORK=mainnet
ENV MAGIC=--mainnet
ENV CARDANO_NODE_SOCKET_PATH=/opt/cardano/ipc/node.socket
