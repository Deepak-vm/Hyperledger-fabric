#!/bin/bash

# Function to print colored text
function println() {
  echo -e "\033[0;32m$1\033[0m"
}

cd ~/fabric-samples/test-network

println "Current Fabric Network Status"
println "==========================="

# Show docker containers
println "Running containers:"
docker ps

# Show channel information for each organization
export FABRIC_CFG_PATH=${PWD}/../config
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Check Org1's channels
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

println "Org1's channels:"
peer channel list

println "Org1's installed chaincodes:"
peer lifecycle chaincode queryinstalled

# Check Org2's channels
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

println "Org2's channels:"
peer channel list

println "Org2's installed chaincodes:"
peer lifecycle chaincode queryinstalled

# Check Org3's channels
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

println "Org3's channels:"
peer channel list

println "Org3's installed chaincodes:"
peer lifecycle chaincode queryinstalled
EOF

chmod +x network-info.sh