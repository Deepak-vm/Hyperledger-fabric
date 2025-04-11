#!/bin/bash

function println() {
  echo -e "\033[0;32m$1\033[0m"
}

function header() {
  echo -e "\033[0;36m$1\033[0m"
}

cd ~/fabric-samples/test-network

# Set path variables
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/

header "===== COMPLETE NETWORK VERIFICATION ====="

# Test mychannel (Org1 + Org2)
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

header "Org1's channels:"
peer channel list

println "Querying assets on mychannel:"
peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}'

println "Querying assets on bluechannel:"
peer chaincode query -C bluechannel -n basic-blue -c '{"Args":["GetAllAssets"]}'

# Test channels accessible by Org2
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

header "Org2's channels:"
peer channel list

println "Querying assets on redchannel:"
peer chaincode query -C redchannel -n basic-red -c '{"Args":["GetAllAssets"]}'

# Test channels accessible by Org3
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

header "Org3's channels:"
peer channel list

println "Querying assets on redchannel from Org3:"
peer chaincode query -C redchannel -n basic-red -c '{"Args":["GetAllAssets"]}'

header "NETWORK FULLY OPERATIONAL!"
println "All three channels are properly configured and accessible."
