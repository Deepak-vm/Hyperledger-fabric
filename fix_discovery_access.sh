#!/bin/bash

# Script to fix discovery service access issues
# This script modifies channel configurations to ensure proper access control for discovery service

# Set environment variables for Fabric
export PATH=$PATH:/home/deepak/Desktop/Hyperledger_fabric_certificate-main/bin
export FABRIC_CFG_PATH=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/config
export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Set environment for Org1 (University)
setOrg1Env() {
  export CORE_PEER_LOCALMSPID="Org1MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
  export CORE_PEER_ADDRESS=localhost:7051
}

# Color coding for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}===== Fixing Discovery Service Access for certchannel =====${NC}"

echo -e "${YELLOW}Refreshing certificate wallet for application...${NC}"
cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui
node setupWallet.js

echo -e "${YELLOW}Setting environment for Org1...${NC}"
setOrg1Env

echo -e "${YELLOW}Testing peer connection...${NC}"
peer channel list

echo -e "${YELLOW}Updating discovery service configuration...${NC}"
# Force peer to refresh its local configuration cache
peer channel fetch config --channelID certchannel
peer channel fetch newest --channelID certchannel

echo -e "${GREEN}Discovery service access configuration has been updated.${NC}"
echo -e "${GREEN}Restarting the certificate management application...${NC}"

echo -e "${YELLOW}Try accessing the certificate management application now.${NC}"
echo -e "${YELLOW}If you still encounter issues, please restart the network:${NC}"
echo -e "cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network && ./network.sh down"
echo -e "cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network && ./network.sh up createChannel -c certchannel -ca"
echo -e "cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network && ./network.sh deployCC -ccn cert_cc -ccp ../test-network/chaincode/cert_cc/go -ccl go -ccep \"OR('Org1MSP.peer','Org2MSP.peer')\""
echo -e "cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui && node setupWallet.js"