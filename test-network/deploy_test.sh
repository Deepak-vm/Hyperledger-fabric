#!/bin/bash

# Make script exit on any error
set -eo pipefail

# Check if network is already running
NETWORK_STATUS=$(docker ps -q -f "name=peer0.org1.example.com" | wc -l)

if [ $NETWORK_STATUS -eq 0 ]; then
  echo "🔧 Step 1: Starting test network and creating channel..."
  cd ~/Desktop/fabric-samples/test-network
  ./network.sh up createChannel -c certchannel
  
  echo "🏢 Step 2: Adding Org3 to the network..."
  cd addOrg3
  ./addOrg3.sh up -c certchannel
  cd ..
else
  echo "🔍 Network is already running. Skipping network creation steps..."
  cd ~/Desktop/fabric-samples/test-network
fi

echo "📦 Step 3: Deploying chaincode cert_cc to Org1 and Org2..."
# Make sure we're in the correct directory
cd ~/Desktop/fabric-samples/test-network

# Verify the chaincode path exists
if [ ! -d "./chaincode/cert_cc/go" ]; then
  echo "❌ Error: Chaincode path does not exist: ./chaincode/cert_cc/go"
  exit 1
fi

# Package and deploy the chaincode properly
./network.sh deployCC -ccn cert_cc -ccp ./chaincode/cert_cc/go -ccl go -c certchannel

echo "🛠 Step 4: Installing chaincode on Org3..."

# Set environment for Org3
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

# Verify the package exists
if [ ! -f "cert_cc.tar.gz" ]; then
  echo "❌ Error: Chaincode package not found. Make sure deployCC created cert_cc.tar.gz"
  exit 1
fi

peer lifecycle chaincode install cert_cc.tar.gz

echo "🔍 Fetching chaincode package ID..."
export PACKAGE_ID=$(peer lifecycle chaincode queryinstalled --output json | jq -r '.installed_chaincodes[0].package_id')

echo "✅ Approving chaincode for Org3..."
peer lifecycle chaincode approveformyorg -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --channelID certchannel \
  --name cert_cc \
  --version 1.0 \
  --package-id $PACKAGE_ID \
  --sequence 1 \
  --tls \
  --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

echo "🏷 Step 5: Issuing certificates from Org1 (UniversityOrg)..."
cd ~/Desktop/fabric-samples/test-network
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# Common TLS variables
ORDERER_CA="${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"
ORG1_CA="${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
ORG2_CA="${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"
ORG3_CA="${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt"

# Wait for chaincode to be ready
echo "⏳ Waiting for chaincode to be ready..."
sleep 10

echo "- Issuing Certificate 1..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" -C certchannel -n cert_cc \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$ORG1_CA" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$ORG2_CA" \
  -c '{"function":"IssueCertificate","Args":["student001","cert001","hash001","UniversityOrg"]}'

echo "- Issuing Certificate 2..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" -C certchannel -n cert_cc \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$ORG1_CA" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$ORG2_CA" \
  -c '{"function":"IssueCertificate","Args":["student002","cert002","hash002","UniversityOrg"]}'

echo "- Issuing Certificate 3..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" -C certchannel -n cert_cc \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$ORG1_CA" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$ORG2_CA" \
  -c '{"function":"IssueCertificate","Args":["student003","cert003","hash003","UniversityOrg"]}'

echo "🚫 Step 6: Attempting to issue certificate as Org2 (should fail)..."
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

# Try to issue a certificate (should fail)
echo "- Attempting to issue as Org2 (StudentOrg)..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile "$ORDERER_CA" \
  -C certchannel -n cert_cc \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$ORG2_CA" \
  -c '{"function":"IssueCertificate","Args":["student004","cert004","hash004","StudentOrg"]}' || echo "- Expected failure: Org2 cannot issue certificates (access control working correctly)"

echo "🚫 Step 7: Attempting to issue certificate as Org3 (should fail)..."
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

# Attempt to issue a certificate using only Org3's peer
echo "- Attempting to issue as Org3 (VerifierOrg)..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
  --cafile "$ORDERER_CA" \
  -C certchannel -n cert_cc \
  --peerAddresses localhost:11051 --tlsRootCertFiles "$ORG3_CA" \
  -c '{"function":"IssueCertificate","Args":["student006","cert006","hash006","VerifierOrg"]}' || echo "- Expected failure: Org3 cannot issue certificates (access control working correctly)"

# Wait for transactions to be processed
echo "⏳ Waiting for transactions to be processed..."
sleep 15

echo "🔍 Step 8: Testing verification capabilities with Org3..."
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

echo "- Org3 verifying certificates..."
echo "  * Certificate 1: $(peer chaincode query -C certchannel -n cert_cc -c '{"function":"VerifyCertificate","Args":["cert001"]}' 2>/dev/null || echo "Error querying")"
echo "  * Certificate 2: $(peer chaincode query -C certchannel -n cert_cc -c '{"function":"VerifyCertificate","Args":["cert002"]}' 2>/dev/null || echo "Error querying")"
echo "  * Certificate 3: $(peer chaincode query -C certchannel -n cert_cc -c '{"function":"VerifyCertificate","Args":["cert003"]}' 2>/dev/null || echo "Error querying")"

echo "🔍 Step 9: Testing verification capabilities with Org2..."
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

echo "- Org2 retrieving certificate details..."
echo "  * Certificate 1 details: $(peer chaincode query -C certchannel -n cert_cc -c '{"function":"GetCertificate","Args":["cert001"]}' 2>/dev/null || echo "Error querying")"
echo "  * Certificate 2 details: $(peer chaincode query -C certchannel -n cert_cc -c '{"function":"GetCertificate","Args":["cert002"]}' 2>/dev/null || echo "Error querying")"
echo "  * Certificate 3 details: $(peer chaincode query -C certchannel -n cert_cc -c '{"function":"GetCertificate","Args":["cert003"]}' 2>/dev/null || echo "Error querying")"

echo "🎉 Done! All tests completed."
