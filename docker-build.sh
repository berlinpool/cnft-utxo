#!/bin/bash
docker build --label psg/nft -t psg/nft:$1 -t psg/nft:latest .
