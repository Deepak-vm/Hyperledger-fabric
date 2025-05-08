#!/bin/bash

# Script to diagnose and fix chaincode issues in the Fabric network
# This will check if chaincode is properly installed and instantiated

# Set environment variables for Fabric
export PATH=$PATH:/home/deepak/Desktop/Hyperledger_fabric_certificate-main/bin
export FABRIC_CFG_PATH=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/config
export CORE_PEER_TLS_ENABLED=true

# Color coding for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}===== Diagnosing Chaincode Issues for Certificate Management UI =====${NC}"

# Set organization 1 environment (University)
function setOrg1Env() {
  export CORE_PEER_LOCALMSPID="Org1MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
  export CORE_PEER_ADDRESS=localhost:7051
  echo -e "${YELLOW}Environment set for Org1 (University)${NC}"
}

# Set organization 2 environment (Student)
function setOrg2Env() {
  export CORE_PEER_LOCALMSPID="Org2MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
  export CORE_PEER_ADDRESS=localhost:9051
  echo -e "${YELLOW}Environment set for Org2 (Student)${NC}"
}

# Check if the 'cert_cc' chaincode is installed and queryable
function checkChaincode() {
  org=$1
  
  echo -e "${YELLOW}Checking if chaincode is accessible for ${org}...${NC}"
  
  # Check if chaincode is installed
  echo -e "${YELLOW}Listing installed chaincode...${NC}"
  peer lifecycle chaincode queryinstalled
  
  # Check if chaincode is committed to the channel
  echo -e "${YELLOW}Checking chaincode definitions committed to channel...${NC}"
  peer lifecycle chaincode querycommitted --channelID certchannel
  
  # Try to query the chaincode
  echo -e "${YELLOW}Attempting to query the GetAllCertificates function...${NC}"
  ORDERER_CA=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
  
  # Try with TLS
  echo -e "${YELLOW}Attempting with TLS...${NC}"
  peer chaincode query -C certchannel -n cert_cc -c '{"Args":["GetAllCertificates"]}' --tls --cafile $ORDERER_CA
  
  # Try without TLS
  echo -e "${YELLOW}Attempting without TLS...${NC}"
  export CORE_PEER_TLS_ENABLED=false
  peer chaincode query -C certchannel -n cert_cc -c '{"Args":["GetAllCertificates"]}'
  export CORE_PEER_TLS_ENABLED=true
}

# Check if we need to deploy or reinstall chaincode
function deployCertCC() {
  echo -e "${YELLOW}Deploying/reinstalling the cert_cc chaincode...${NC}"
  cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network
  
  # First, check if test network is running
  CONTAINERS=$(docker ps | grep hyperledger | wc -l)
  if [ "$CONTAINERS" -lt 3 ]; then
    echo -e "${RED}Error: Hyperledger Fabric containers are not running.${NC}"
    echo -e "${YELLOW}Starting the test network with the channel...${NC}"
    ./network.sh down
    ./network.sh up createChannel -c certchannel
  fi
  
  # Now deploy the chaincode
  echo -e "${YELLOW}Deploying chaincode cert_cc...${NC}"
  ./network.sh deployCC -ccn cert_cc -ccp ../certificate-management-ui/chaincode -ccl go
  
  echo -e "${GREEN}Chaincode deployment completed!${NC}"
}

# Fix for "Query failed. Errors: []" issue
function fixQueryError() {
  echo -e "${YELLOW}Fixing 'Query failed. Errors: []' issue...${NC}"
  
  # Refresh wallet
  cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui
  echo -e "${YELLOW}Setting up wallet again...${NC}"
  node setupWallet.js
  
  # Create a test certificate if none exists
  echo -e "${YELLOW}Creating test certificate...${NC}"
  
  # Set environment to Org1 for issuing certificate
  setOrg1Env
  
  # Use peer CLI directly to issue a test certificate
  ORDERER_CA=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
  ORG1_CA=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
  ORG2_CA=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
  
  # Issue test certificate
  peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile $ORDERER_CA -C certchannel -n cert_cc \
    --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_CA \
    --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_CA \
    -c '{"function":"IssueCertificate","Args":["student001","cert001","hash001","UniversityOrg"]}'
  
  echo -e "${GREEN}Issue test certificate command completed!${NC}"
  
  # Wait for transaction to be processed
  sleep 5
  
  # Now check if the certificate exists
  echo -e "${YELLOW}Checking if test certificate was created...${NC}"
  peer chaincode query -C certchannel -n cert_cc -c '{"Args":["GetCertificate", "cert001"]}' --tls --cafile $ORDERER_CA
}

# Main execution
echo -e "${YELLOW}===== Starting Chaincode Diagnosis =====${NC}"

# Setting Org1 environment
setOrg1Env

# Check chaincode for Org1
checkChaincode "Org1"

# Attempt to fix issues
echo -e "${YELLOW}===== Attempting to fix issues =====${NC}"
fixQueryError

echo -e "${GREEN}===== Diagnosis and fixes completed! =====${NC}"
echo -e "${YELLOW}Now try running the application again: npm run dev${NC}"

# Create index file for CouchDB
echo -e "${YELLOW}Checking if we need to create CouchDB indexes...${NC}"
cat > index.json << EOF
{
  "index": {
    "fields": ["docType", "issuer", "recipient"]
  },
  "ddoc": "indexCertificateDoc",
  "name": "indexCertificate",
  "type": "json"
}
EOF

echo -e "${YELLOW}=========== Final checks and recommendations ============${NC}"
echo -e "${YELLOW}1. If you're still experiencing issues, try restarting the network:${NC}"
echo -e "   cd ../test-network"
echo -e "   ./network.sh down"
echo -e "   ./network.sh up createChannel -c certchannel -ca"
echo -e "   ./network.sh deployCC -ccn cert_cc -ccp ../certificate-management-ui/chaincode -ccl go"
echo -e ""
echo -e "${YELLOW}2. Make sure your chaincode has proper GetAllCertificates function:${NC}"
echo -e "   The function might be returning empty results or experiencing an error."
echo -e ""
echo -e "${YELLOW}3. Check the NodeJS application:${NC}"
echo -e "   Try directly querying the chaincode using the CLI commands shown above."
echo -e ""
echo -e "${GREEN}Script complete. Now restart your application with:${NC}"
echo -e "   cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui"
echo -e "   npm run dev"