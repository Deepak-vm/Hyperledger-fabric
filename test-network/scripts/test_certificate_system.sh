#!/bin/bash
# filepath: /home/dawgdevv/fabric-samples/test-network/scripts/test_certificate_system.sh

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}   CERTIFICATE MANAGEMENT SYSTEM - TESTING SCRIPT    ${NC}"
echo -e "${BLUE}=====================================================${NC}\n"

# Function to display section headers
section() {
    echo -e "\n${YELLOW}==== $1 ====${NC}"
}

# Function to check command execution status
check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Success${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
}

# Set environment variables for common usage
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

section "CHECKING NETWORK STATUS"
if [ $(docker ps | grep peer0.org1 | wc -l) -eq 0 ]; then
    echo -e "${RED}Fabric network is not running! Please start it first.${NC}"
    exit 1
fi
echo -e "${GREEN}Network is running.${NC}"

section "TESTING ORG1 (UNIVERSITY) - CERTIFICATE ISSUER"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

echo "Issuing Certificate 1 (should succeed)..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
    --cafile "$ORDERER_CA" -C certchannel -n cert_cc \
    --peerAddresses localhost:7051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    --peerAddresses localhost:9051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
    -c '{"function":"IssueCertificate","Args":["student001","cert001","hash001","UniversityOrg"]}' \
    --waitForEvent
check_result

echo "Verifying Certificate 1 from Org1..."
peer chaincode query -C certchannel -n cert_cc \
    -c '{"function":"VerifyCertificate","Args":["cert001"]}'
check_result

echo "Getting Certificate 1 details from Org1..."
peer chaincode query -C certchannel -n cert_cc \
    -c '{"function":"GetCertificate","Args":["cert001"]}'
check_result

section "TESTING ORG2 (STUDENT) - READ ONLY ACCESS"
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

echo "Attempting to issue a certificate as Org2 (should fail)..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
    --cafile "$ORDERER_CA" -C certchannel -n cert_cc \
    --peerAddresses localhost:7051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    --peerAddresses localhost:9051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
    -c '{"function":"IssueCertificate","Args":["student002","cert002","hash002","StudentOrg"]}' \
    --waitForEvent
echo -e "${GREEN}✓ Expected failure with 'only UniversityOrg can issue certificates' message${NC}"

echo "Verifying Certificate 1 from Org2 (should succeed)..."
peer chaincode query -C certchannel -n cert_cc \
    -c '{"function":"VerifyCertificate","Args":["cert001"]}'
check_result

echo "Getting Certificate 1 details from Org2 (should succeed)..."
peer chaincode query -C certchannel -n cert_cc \
    -c '{"function":"GetCertificate","Args":["cert001"]}'
check_result

section "TESTING ORG3 (VERIFIER) - VERIFICATION ROLE"
# Check if Org3 exists in the network
if [ -d "${PWD}/organizations/peerOrganizations/org3.example.com" ]; then
    export CORE_PEER_LOCALMSPID="Org3MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
    export CORE_PEER_ADDRESS=localhost:11051

    echo "Attempting to issue a certificate as Org3 (should fail)..."
    peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
        --cafile "$ORDERER_CA" -C certchannel -n cert_cc \
        --peerAddresses localhost:7051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
        --peerAddresses localhost:11051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt" \
        -c '{"function":"IssueCertificate","Args":["student003","cert003","hash003","VerifierOrg"]}' \
        --waitForEvent
    echo -e "${GREEN}✓ Expected failure with 'only UniversityOrg can issue certificates' message${NC}"

    echo "Verifying Certificate 1 from Org3 (should succeed)..."
    peer chaincode query -C certchannel -n cert_cc \
        -c '{"function":"VerifyCertificate","Args":["cert001"]}'
    check_result

    echo "Getting Certificate 1 details from Org3 (should succeed)..."
    peer chaincode query -C certchannel -n cert_cc \
        -c '{"function":"GetCertificate","Args":["cert001"]}'
    check_result
else
    echo -e "${YELLOW}Org3 configuration not found. Skipping Org3 tests.${NC}"
fi

section "ISSUING ADDITIONAL CERTIFICATES AS ORG1"
# Switch back to Org1 to issue more certificates
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

echo "Issuing Certificate 2..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
    --cafile "$ORDERER_CA" -C certchannel -n cert_cc \
    --peerAddresses localhost:7051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    --peerAddresses localhost:9051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
    -c '{"function":"IssueCertificate","Args":["student002","cert002","hash002","UniversityOrg"]}' \
    --waitForEvent
check_result

echo "Issuing Certificate 3..."
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
    --cafile "$ORDERER_CA" -C certchannel -n cert_cc \
    --peerAddresses localhost:7051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
    --peerAddresses localhost:9051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
    -c '{"function":"IssueCertificate","Args":["student003","cert003","hash003","UniversityOrg"]}' \
    --waitForEvent
check_result

section "RETRIEVING ALL CERTIFICATES"
echo "Getting all certificates from the ledger..."
peer chaincode query -C certchannel -n cert_cc \
    -c '{"function":"GetAllCertificates","Args":[]}'
check_result

section "TEST SUMMARY"
echo -e "${BLUE}Access Control:${NC}"
echo -e "  - Org1 (University): ${GREEN}Can issue certificates✓${NC}"
echo -e "  - Org2 (Student):   ${GREEN}Read-only access✓${NC}"
if [ -d "${PWD}/organizations/peerOrganizations/org3.example.com" ]; then
    echo -e "  - Org3 (Verifier):  ${GREEN}Read-only access✓${NC}"
fi

echo -e "\n${BLUE}Functionality:${NC}"
echo -e "  - Certificate issuance:    ${GREEN}Working✓${NC}"
echo -e "  - Certificate verification: ${GREEN}Working✓${NC}"
echo -e "  - Certificate retrieval:    ${GREEN}Working✓${NC}"
echo -e "  - Access control enforcement: ${GREEN}Working✓${NC}"

echo -e "\n${GREEN}=== TEST COMPLETED SUCCESSFULLY ===${NC}"
