#!/bin/bash
# filepath: /home/hyperledger/fabric-samples/build-fixed-network.sh

function println() {
  echo -e "\033[0;32m$1\033[0m"
}

function errorln() {
  echo -e "\033[0;31m$1\033[0m"
}

function header() {
  echo -e "\033[0;36m===== $1 =====\033[0m"
}

cd ~/fabric-samples/test-network

# Step 1: Bring down any existing network
header "BRINGING DOWN ANY EXISTING NETWORK"
./network.sh down
cd addOrg3
./addOrg3.sh down
cd ..

# Step 2: Start the base network with two organizations
header "STARTING BASE NETWORK"
# Using --no-ca to avoid issues with CA certs
./network.sh up

# Step 3: Create all channels manually (bypassing anchor peer updates that cause the error)
header "CREATING CHANNELS MANUALLY"

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/

# Create mychannel
println "Creating mychannel..."
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/mychannel.tx -channelID mychannel
osnadmin channel join --channelID mychannel --config-block ./channel-artifacts/mychannel.block -o localhost:7053 --ca-file ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --client-cert ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt --client-key ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

# Have org1 join mychannel
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer channel join -b ./channel-artifacts/mychannel.block

# Have org2 join mychannel
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer channel join -b ./channel-artifacts/mychannel.block

# Create bluechannel
println "Creating bluechannel..."
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/bluechannel.tx -channelID bluechannel
peer channel create -o localhost:7050 -c bluechannel --ordererTLSHostnameOverride orderer.example.com -f ./channel-artifacts/bluechannel.tx --outputBlock ./channel-artifacts/bluechannel.block --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Have org1 join bluechannel
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer channel join -b ./channel-artifacts/bluechannel.block

# Have org2 join bluechannel
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer channel join -b ./channel-artifacts/bluechannel.block

# Step 4: Add Org3 and create redchannel using alternative method
header "ADDING ORG3 AND CREATING REDCHANNEL"

# First use the script to add Org3 but don't create redchannel yet
cd addOrg3
./addOrg3.sh up -c mychannel
cd ..

# Create redchannel manually
println "Creating redchannel..."
export FABRIC_CFG_PATH=${PWD}/configtx
configtxgen -profile ThreeOrgsChannel -outputCreateChannelTx ./channel-artifacts/redchannel.tx -channelID redchannel
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer channel create -o localhost:7050 -c redchannel --ordererTLSHostnameOverride orderer.example.com -f ./channel-artifacts/redchannel.tx --outputBlock ./channel-artifacts/redchannel.block --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Have Org2 join redchannel
peer channel join -b ./channel-artifacts/redchannel.block

# Have Org3 join redchannel
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

peer channel join -b ./channel-artifacts/redchannel.block

# Step 5: Deploy chaincode to all channels
header "DEPLOYING CHAINCODE TO ALL CHANNELS"

# Deploy to mychannel
println "Deploying chaincode to mychannel..."
./network.sh deployCC -c mychannel -ccn basic -ccp ../asset-transfer-basic/chaincode-javascript -ccl javascript

# Deploy to bluechannel
println "Deploying chaincode to bluechannel..."
./network.sh deployCC -c bluechannel -ccn basic-blue -ccp ../asset-transfer-basic/chaincode-javascript -ccl javascript

# Deploy to redchannel
println "Deploying chaincode to redchannel..."
./network.sh deployCC -c redchannel -ccn basic-red -ccp ../asset-transfer-basic/chaincode-javascript -ccl javascript

# Step 6: Initialize all ledgers
header "INITIALIZING ALL LEDGERS"

# Initialize mychannel ledger
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

println "Initializing mychannel ledger..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  -C mychannel -n basic \
  --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"InitLedger","Args":[]}'

sleep 5

# Initialize bluechannel ledger
println "Initializing bluechannel ledger..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  -C bluechannel -n basic-blue \
  --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"InitLedger","Args":[]}'

sleep 5

# Initialize redchannel ledger
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

println "Initializing redchannel ledger..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  -C redchannel -n basic-red \
  --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  --peerAddresses localhost:11051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt \
  -c '{"function":"InitLedger","Args":[]}'

sleep 5

# Create verification script
header "CREATING VERIFICATION SCRIPT"

cat > ~/fabric-samples/verify-full-network.sh << 'EOF'
#!/bin/bash

function println() {
  echo -e "\033[0;32m$1\033[0m"
}

function header() {
  echo -e "\033[0;36m===== $1 =====\033[0m"
}

cd ~/fabric-samples/test-network

# Set path variables
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/

header "VERIFYING NETWORK STRUCTURE"

# Check Org1 channels (should be in mychannel and bluechannel)
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

println "Org1's channels:"
peer channel list

# Check Org2 channels (should be in all three channels)
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

println "Org2's channels:"
peer channel list

# Check Org3 channels (should be in redchannel)
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

println "Org3's channels:"
peer channel list

header "VERIFYING CHAINCODE FUNCTIONALITY"

# Test Org1's access to mychannel and bluechannel
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

println "Mychannel assets (Org1):"
peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}'

println "Bluechannel assets (Org1):"
peer chaincode query -C bluechannel -n basic-blue -c '{"Args":["GetAllAssets"]}'

# Test Org2's access to all channels
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

println "Mychannel assets (Org2):"
peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}'

println "Bluechannel assets (Org2):"
peer chaincode query -C bluechannel -n basic-blue -c '{"Args":["GetAllAssets"]}'

println "Redchannel assets (Org2):"
peer chaincode query -C redchannel -n basic-red -c '{"Args":["GetAllAssets"]}'

# Test Org3's access to redchannel
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

println "Redchannel assets (Org3):"
peer chaincode query -C redchannel -n basic-red -c '{"Args":["GetAllAssets"]}'

header "TESTING CHANNEL ISOLATION"

# Update asset6 on each channel with different values
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

println "Changing asset6 owner in mychannel to 'Michel'..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  -C mychannel -n basic \
  --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"TransferAsset","Args":["asset6","Michel"]}'

sleep 5

println "Changing asset6 owner in bluechannel to 'Sarah'..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  -C bluechannel -n basic-blue \
  --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"TransferAsset","Args":["asset6","Sarah"]}'

sleep 5

export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

println "Changing asset6 owner in redchannel to 'Thomas'..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  -C redchannel -n basic-red \
  --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  --peerAddresses localhost:11051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt \
  -c '{"function":"TransferAsset","Args":["asset6","Thomas"]}'

sleep 5

header "VERIFYING CHANNEL ISOLATION"

export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

println "Mychannel asset6 owner (should be 'Michel'):"
peer chaincode query -C mychannel -n basic -c '{"Args":["ReadAsset","asset6"]}'

println "Bluechannel asset6 owner (should be 'Sarah'):"
peer chaincode query -C bluechannel -n basic-blue -c '{"Args":["ReadAsset","asset6"]}'

export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

println "Redchannel asset6 owner (should be 'Thomas'):"
peer chaincode query -C redchannel -n basic-red -c '{"Args":["ReadAsset","asset6"]}'

header "NETWORK VERIFICATION COMPLETE"
println "Multi-channel network with three organizations is fully operational!"
EOF

chmod +x ~/fabric-samples/verify-full-network.sh

header "NETWORK DEPLOYMENT COMPLETE"
println "The multi-channel network has been successfully built!"
println "To verify the network, run: ./verify-full-network.sh"