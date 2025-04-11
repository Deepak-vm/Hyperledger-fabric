#!/bin/bash
# filepath: /home/hyperledger/fabric-samples/simple-multi-channel-setup.sh

# Function to print colored text
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

# Backup existing configtx.yaml and fix it
cp configtx/configtx.yaml configtx/configtx.yaml.bak

# Fix the configtx.yaml file before starting
cd ~/fabric-samples
./fix-configtx.sh

cd ~/fabric-samples/test-network

# Start the network with CA
println "Starting the network with Certificate Authorities..."
./network.sh up -ca
sleep 3

# Create mychannel using the built-in script
println "Creating mychannel..."
./network.sh createChannel -c mychannel
sleep 3

# Add Org3 to mychannel
println "Adding Org3 to the network..."
cd addOrg3
./addOrg3.sh up -c mychannel
cd ..
sleep 3

# Create bluechannel
println "Creating bluechannel..."
./network.sh createChannel -c bluechannel
sleep 3

# Create redchannel
println "Creating redchannel..."
./network.sh createChannel -c redchannel
sleep 3

# Join Org3 to redchannel (since network.sh only adds Org1 and Org2)
println "Joining Org3 to redchannel..."
export FABRIC_CFG_PATH=${PWD}/../config
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

mkdir -p channel-artifacts
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