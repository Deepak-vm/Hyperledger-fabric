#!/bin/bash
# filepath: /home/hyperledger/fabric-samples/final-redchannel-fix.sh

function println() {
  echo -e "\033[0;32m$1\033[0m"
}

function errorln() {
  echo -e "\033[0;31m$1\033[0m"
}

cd ~/fabric-samples/test-network

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/

# First make sure Org3 can be properly accessed
println "======== VERIFYING ORG3 ACCESS ========"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

# Test if we can interact with Org3
peer channel list
if [ $? -ne 0 ]; then
  errorln "Cannot communicate with Org3 peer. Let's ensure Org3 is properly added."
  cd addOrg3
  ./addOrg3.sh down
  ./addOrg3.sh up -c redchannel
  cd ..
  # Re-export environment variables
  export CORE_PEER_LOCALMSPID="Org3MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
  export CORE_PEER_ADDRESS=localhost:11051
  peer channel list
fi

println "======== DEPLOYING CHAINCODE WITH CORRECT SEQUENCE NUMBER ========"

# Package chaincode
println "Packaging chaincode..."
peer lifecycle chaincode package basic-red.tar.gz \
  --path ../asset-transfer-basic/chaincode-javascript \
  --lang node \
  --label basic-red_1.0

# Install on all three organizations
# Install on Org1
println "Installing on Org1..."
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer lifecycle chaincode install basic-red.tar.gz

# Install on Org2
println "Installing on Org2..."
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
peer lifecycle chaincode install basic-red.tar.gz

# Install on Org3
println "Installing on Org3..."
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051
peer lifecycle chaincode install basic-red.tar.gz

# Get package ID
PACKAGE_ID=$(peer lifecycle chaincode queryinstalled --output json | jq -r '.installed_chaincodes[] | select(.label=="basic-red_1.0") | .package_id')
println "Package ID: ${PACKAGE_ID}"

# IMPORTANT: Using sequence 3 as required by the error message
SEQUENCE=3

# Approve for Org1
println "Approving for Org1..."
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer lifecycle chaincode approveformyorg -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  --channelID redchannel --name basic-red --version 1.0 \
  --package-id ${PACKAGE_ID} --sequence ${SEQUENCE}

# Approve for Org2
println "Approving for Org2..."
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
peer lifecycle chaincode approveformyorg -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  --channelID redchannel --name basic-red --version 1.0 \
  --package-id ${PACKAGE_ID} --sequence ${SEQUENCE}

# Approve for Org3 - Make sure Org3 MSP is correct
println "Approving for Org3..."
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

# Check channel membership before approving
println "Checking Org3 channel membership..."
CHANNELS=$(peer channel list)
if [[ $CHANNELS == *"redchannel"* ]]; then
  println "Org3 is a member of redchannel, proceeding with approval"
  peer lifecycle chaincode approveformyorg -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com --tls \
    --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
    --channelID redchannel --name basic-red --version 1.0 \
    --package-id ${PACKAGE_ID} --sequence ${SEQUENCE}
else
  errorln "Org3 is NOT a member of redchannel. Cannot proceed."
  exit 1
fi

# Check commit readiness
println "Checking commit readiness..."
peer lifecycle chaincode checkcommitreadiness \
  --channelID redchannel --name basic-red \
  --version 1.0 --sequence ${SEQUENCE} --output json

# Commit the chaincode definition
println "Committing chaincode definition..."
peer lifecycle chaincode commit -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  --channelID redchannel --name basic-red --version 1.0 --sequence ${SEQUENCE} \
  --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  --peerAddresses localhost:11051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt

# Wait for chaincode container to start
println "Waiting for chaincode container to start..."
sleep 15

# Initialize the ledger
println "Initializing the ledger..."
peer chaincode invoke -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  -C redchannel -n basic-red \
  --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  --peerAddresses localhost:11051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt \
  -c '{"function":"InitLedger","Args":[]}'

sleep 5

# Verify the ledger was initialized
println "Verifying the ledger was initialized..."
peer chaincode query -C redchannel -n basic-red -c '{"Args":["GetAllAssets"]}'

println "======== CREATION OF FINAL VERIFICATION SCRIPT ========"
cat > ~/fabric-samples/verify-complete-network.sh << 'EOF'
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
EOF

chmod +x ~/fabric-samples/verify-complete-network.sh
println "Redchannel has been fixed. Run ./verify-complete-network.sh to verify all channels."