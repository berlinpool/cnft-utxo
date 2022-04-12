#
# Image build: (builds cardano-cli, token-name and token-policy binary)
# (1) Build stage:
#	- install nix
#	- set up IOHK binary cache
#   - checkout plutus-apps & nft repository
#	- build plutus binaries using nix-shell 
#     - install nft binaries via cabal
#     - copy cardano-cli binary to /usr/local/bin
#   - extract required dynamically linked libraries from all three target binaries
#       - copy libs to temporary nix store (/tmp/nix-store)
# (2) RUN stage:
#	- copy minimized temporary nix store to executable container
#	- copy target binaries to executable container
#	- copy mint cli script and auxiliary files to /usr/local/etc
#	- update PATH to include binaries
#  	- set CMD and ENTRYPOINT to run docker container as executable with respective
#	  default values provided in docker volume
#	- set up environment variables with default values

#                                                                              #
# --------------------------------- BUILD ------------------------------------ #
#                                                                              #

FROM ubuntu:20.04 AS builder

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

RUN git clone https://github.com/input-output-hk/plutus-apps.git /tmp/plutus-apps/
WORKDIR /tmp/plutus-apps/
# Git commit id must match cabal.project tag
RUN git checkout $COMMIT_ID
# Set PATH to include .nix_profile & cabal/bin path to run nix-shell & find binaries
ENV PATH="$PATH:/nix/var/nix/profiles/default/bin:/usr/local/bin:/bin:/root/.cabal/bin"
# Cache expensive command - builds all plutus dependencies
RUN nix-shell

WORKDIR /tmp
# the following prevent docker caching via github's versioning as the head changes
ADD https://api.github.com/repos/william-wolff-io/nft-maker/git/refs/heads/master version.json
RUN git clone https://github.com/william-wolff-io/nft-maker.git /tmp/nft/
# Build binaries required for plutus & nft repository
WORKDIR /tmp/plutus-apps/
RUN nix-shell --run 'cd /tmp/nft/ && cabal update && cabal install && cp $(which cardano-cli) /usr/local/bin/cardano-cli 2>&1'
RUN /tmp/nft/scripts/build/build-nft-binaries-store.sh

ENTRYPOINT [ "/bin/bash" ]

#                                                                              #
# --------------------------------- PROD ------------------------------------- #
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

FROM ubuntu:20.04

RUN apt-get update && apt-get install --no-install-recommends -y jq

# Copy nix depdencies
COPY --from=builder /tmp/nix-store/nix /nix
# Copy binaries
COPY --from=builder /root/.cabal/bin/token-name /usr/local/bin
COPY --from=builder /root/.cabal/bin/token-policy /usr/local/bin
COPY --from=builder /usr/local/bin/cardano-cli /usr/local/bin

# Copy script & auxiliary files
COPY --from=builder /tmp/nft/scripts/mint/create-metadata.sh /usr/local/etc/create-metadata.sh
COPY --from=builder /tmp/nft/scripts/mint/mint-token-cli.sh /usr/local/etc/mint-token-cli.sh
COPY --from=builder /tmp/nft/testnet/unit.json /usr/local/etc/unit.json

ENTRYPOINT [ "/usr/local/etc/mint-token-cli.sh" ]
CMD [ "utxo", "tokenname", "payment.addr", "payment.skey" ]

ENV SCRIPT_PATH=/usr/local/etc
ENV INPUTS_DIR=/var/cardano/inputs
ENV NETWORK=mainnet
ENV CARDANO_NODE_SOCKET_PATH=/opt/cardano/ipc/node.socket
