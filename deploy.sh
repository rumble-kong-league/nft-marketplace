#!/bin/bash

RPC_URL=$1
PRIVATE_KEY=$2
ETHERSCAN_KEY=$3

forge create --rpc-url $1 \
    --private-key $2 src/Marketplace.sol:Marketplace \
    --etherscan-api-key $3 \
    --verify