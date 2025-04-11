#!/bin/bash
# filepath: /home/hyperledger/fabric-samples/minimal-multi-channel.sh

# Exit on first error
set -e

function println() {
  echo -e "\033[0;32m$1\033[0m"
}

cd ~/fabric-samples/test-network

# Clean up previous network
println "Cleaning up previous network..."
./network.sh down
cd addOrg3
./addOrg3.sh down
cd ..

# Start network with crypto materials
println "Starting network with CA..."
./network.sh up -ca
sleep 3

# Create mychannel
println "Creating mychannel..."
./network.sh createChannel -c mychannel
sleep 3

# Add Org3 to mychannel
println "Adding Org3 to mychannel..."
cd addOrg3
./addOrg3.sh up -c mychannel
cd ..
sleep 3

# Helper function to create additional channel
create_channel() {
  CHANNEL=$1
  CREATOR_ORG=$2
  
  println "Creating $CHANNEL..."
  
  # Set environment for the specified organization
  if [ "$CREATOR_ORG" = "1" ]; then
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
  elif [ "$CREATOR_ORG" = "2" ]; then
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051
  fi
  
  # Create channel using the network.sh script (uses TwoOrgsChannel)
  ./network.sh createChannel -c $CHANNEL
}

# Create bluechannel (Org1 and Org2)
create_channel bluechannel 1

# Create redchannel (created by Org2, will add Org3 later)
create_channel redchannel 2

# Join Org3 to redchannel
println "Joining Org3 to redchannel..."
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
peer channel fetch 0 ./channel-artifacts/redchannel.block -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c redchannel --tls --cafile "$ORDERER_CA"
peer channel join -b ./channel-artifacts/redchannel.block

# Verify channel membership
println "Verifying channel membership..."

# Check Org1's channels
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

println "Org1's channels:"
peer channel list

# Check Org2's channels
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

println "Org2's channels:"
peer channel list

# Check Org3's channels
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

println "Org3's channels:"
peer channel list

println "Multi-channel network setup complete!"