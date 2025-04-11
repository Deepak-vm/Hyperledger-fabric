#!/bin/bash

# Exit on first error
set -e

function println() {
  echo -e "\033[0;32m$1\033[0m"
}

cd ~/fabric-samples/test-network

# Set path for fabric binaries
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/

# Deploy JavaScript chaincode instead of Go
println "Deploying JavaScript chaincode to mychannel..."
./network.sh deployCC -c mychannel -ccn basic -ccp ../asset-transfer-basic/chaincode-javascript -ccl javascript

println "Deploying JavaScript chaincode to bluechannel..."
./network.sh deployCC -c bluechannel -ccn basic-blue -ccp ../asset-transfer-basic/chaincode-javascript -ccl javascript

println "Deploying JavaScript chaincode to redchannel..."
./network.sh deployCC -c redchannel -ccn basic-red -ccp ../asset-transfer-basic/chaincode-javascript -ccl javascript

println "All JavaScript chaincode deployments complete!"