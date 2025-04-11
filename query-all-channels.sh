#!/bin/bash
# filepath: /home/hyperledger/fabric-samples/query-all-channels.sh

function println() {
  echo -e "\033[0;32m$1\033[0m"
}

cd ~/fabric-samples/test-network

# Set environment for Org1
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# Query mychannel
println "Querying assets on mychannel..."
peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}'

# Query bluechannel
println "Querying assets on bluechannel..."
peer chaincode query -C bluechannel -n basic-blue -c '{"Args":["GetAllAssets"]}'

# Set environment for Org2 to query redchannel
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

# Query redchannel
println "Querying assets on redchannel..."
peer chaincode query -C redchannel -n basic-red -c '{"Args":["GetAllAssets"]}'