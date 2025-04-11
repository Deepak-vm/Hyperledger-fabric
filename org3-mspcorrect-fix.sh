#!/bin/bash
# filepath: /home/hyperledger/fabric-samples/build-complete-network.sh

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
./network.sh up createChannel -c mychannel -ca
if [ $? -ne 0 ]; then
  errorln "Failed to start network. Exiting."
  exit 1
fi

# Step 3: Create bluechannel
header "CREATING BLUECHANNEL"
./network.sh createChannel -c bluechannel
if [ $? -ne 0 ]; then
  errorln "Failed to create bluechannel. Exiting."
  exit 1
fi

# Step 4: Add Org3 and create redchannel
header "ADDING ORG3 AND CREATING REDCHANNEL"
cd addOrg3
./addOrg3.sh up -c redchannel
if [ $? -ne 0 ]; then
  errorln "Failed to add Org3 and create redchannel. Exiting."
  exit 1
fi
cd ..

# Step 5: Deploy chaincode to all channels
header "DEPLOYING CHAINCODE TO MYCHANNEL"
./network.sh deployCC -c mychannel -ccn basic -ccp ../asset-transfer-basic/chaincode-javascript -ccl javascript
if [ $? -ne 0 ]; then
  errorln "Failed to deploy chaincode to mychannel. Exiting."
  exit 1
fi

header "DEPLOYING CHAINCODE TO BLUECHANNEL"
./network.sh deployCC -c bluechannel -ccn basic-blue -ccp ../asset-transfer-basic/chaincode-javascript -ccl javascript
if [ $? -ne 0 ]; then
  errorln "Failed to deploy chaincode to bluechannel. Exiting."
  exit 1
fi

header "DEPLOYING CHAINCODE TO REDCHANNEL"
./network.sh deployCC -c redchannel -ccn basic-red -ccp ../asset-transfer-basic/chaincode-javascript -ccl javascript
if [ $? -ne 0 ]; then
  errorln "Failed to deploy chaincode to redchannel. Exiting."
  exit 1
fi

# Step 6: Initialize all ledgers
header "INITIALIZING ALL LEDGERS"

# For mychannel (Org1+Org2)
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/
export CORE_PEER_TLS_ENABLED=true
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

# For bluechannel (Org1+Org2)
println "Initializing bluechannel ledger..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  -C bluechannel -n basic-blue \
  --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"InitLedger","Args":[]}'

sleep 5

# For redchannel (Org2+Org3)
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

# Step 7: Create verification script
header "CREATING VERIFICATION SCRIPT"

cat > ~/fabric-samples/verify-network.sh << 'EOF'
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

header "VERIFYING ALL CHANNELS"

# Verify as Org1
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

println "Org1's channels:"
peer channel list

println "Querying assets on mychannel:"
peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}'

println "Querying assets on bluechannel:"
peer chaincode query -C bluechannel -n basic-blue -c '{"Args":["GetAllAssets"]}'

# Verify as Org2
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

println "Org2's channels:"
peer channel list

println "Querying assets on redchannel:"
peer chaincode query -C redchannel -n basic-red -c '{"Args":["GetAllAssets"]}'

# Verify as Org3
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

println "Org3's channels:"
peer channel list

println "Querying assets on redchannel from Org3:"
peer chaincode query -C redchannel -n basic-red -c '{"Args":["GetAllAssets"]}'

header "TESTING CHANNEL ISOLATION"

# As Org1, change asset6 in mychannel
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

sleep 3

# As Org1, change asset6 in bluechannel
println "Changing asset6 owner in bluechannel to 'Sarah'..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  -C bluechannel -n basic-blue \
  --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"TransferAsset","Args":["asset6","Sarah"]}'

sleep 3

# As Org2, change asset6 in redchannel
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

sleep 3

header "VERIFYING CHANNEL ISOLATION"

# Verify as Org1
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

println "Mychannel asset6 owner should be 'Michel':"
peer chaincode query -C mychannel -n basic -c '{"Args":["ReadAsset","asset6"]}'

println "Bluechannel asset6 owner should be 'Sarah':"
peer chaincode query -C bluechannel -n basic-blue -c '{"Args":["ReadAsset","asset6"]}'

# Verify as Org2
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

println "Redchannel asset6 owner should be 'Thomas':"
peer chaincode query -C redchannel -n basic-red -c '{"Args":["ReadAsset","asset6"]}'

header "NETWORK VERIFICATION COMPLETE"
println "Multi-channel network is fully operational with proper isolation!"
EOF

chmod +x ~/fabric-samples/verify-network.sh

header "NETWORK DEPLOYMENT COMPLETE"
println "The multi-channel network has been successfully built."
println "To verify the network, run: ./verify-network.sh"