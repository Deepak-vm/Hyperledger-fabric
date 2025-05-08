#!/bin/bash

# Script to add Org3 to the test network for Verifier functionality
# This script should be run from the certificate-management-ui directory

echo "🛠️  Setting up Org3 (Verifier) for the Certificate Management UI..."

# Navigate to the test network directory
cd ../test-network || {
  echo "❌ Error: Could not find test-network directory"
  exit 1
}

# Check if the network is running
if [ ! -d "./organizations/peerOrganizations/org1.example.com" ]; then
  echo "❌ Error: Test network doesn't seem to be running."
  echo "   Please start the network first with: ./network.sh up createChannel -c certchannel"
  exit 1
fi

# Check if Org3 is already set up
if [ -d "./organizations/peerOrganizations/org3.example.com" ]; then
  echo "✅ Org3 appears to be already set up!"
else
  echo "🔍 Org3 not found. Adding Org3 to the network..."
  
  # Navigate to addOrg3 directory
  cd addOrg3 || {
    echo "❌ Error: Could not find addOrg3 directory"
    exit 1
  }
  
  # Add Org3 to the channel
  echo "🏗️  Running addOrg3.sh to add Org3 to the network..."
  ./addOrg3.sh up -c certchannel
  
  if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to add Org3 to the network"
    exit 1
  fi
  
  cd ..
fi

# Install chaincode on Org3
echo "📦 Installing chaincode on Org3..."

# Set environment variables for Org3
export FABRIC_CFG_PATH=${PWD}/../config/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

# Check if the chaincode is already installed
PACKAGE_ID=$(peer lifecycle chaincode queryinstalled --output json 2>/dev/null | grep -o '"cert_cc:[^"]*"' | head -1 | sed 's/"//g')

if [ -z "$PACKAGE_ID" ]; then
  echo "❓ Chaincode not found on Org3. Checking existing chaincode on the network..."
  
  # Get the chaincode package ID from Org1
  export CORE_PEER_LOCALMSPID="Org1MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
  export CORE_PEER_ADDRESS=localhost:7051
  
  ORG1_PACKAGE_ID=$(peer lifecycle chaincode queryinstalled --output json | grep -o '"cert_cc:[^"]*"' | head -1 | sed 's/"//g')
  
  if [ -z "$ORG1_PACKAGE_ID" ]; then
    echo "❌ Error: Certificate chaincode 'cert_cc' not found on the network."
    echo "   Please deploy the chaincode with: ./network.sh deployCC -ccn cert_cc -ccp ./chaincode/cert_cc/go -ccl go -c certchannel"
    exit 1
  fi
  
  # Switch back to Org3
  export CORE_PEER_LOCALMSPID="Org3MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
  export CORE_PEER_ADDRESS=localhost:11051
  
  # Get the chaincode package
  echo "📥 Finding chaincode package..."
  CHAINCODE_PACKAGE=$(find . -name "cert_cc*.tar.gz" | head -1)
  
  if [ -z "$CHAINCODE_PACKAGE" ]; then
    echo "❌ Error: Cannot find chaincode package file."
    echo "   Please make sure the chaincode is deployed properly on the network."
    exit 1
  fi
  
  # Install the chaincode on Org3
  echo "📥 Installing chaincode package on Org3..."
  peer lifecycle chaincode install "$CHAINCODE_PACKAGE"
  
  # Get the installed package ID
  PACKAGE_ID=$(peer lifecycle chaincode queryinstalled --output json | grep -o '"cert_cc:[^"]*"' | head -1 | sed 's/"//g')
fi

echo "🔍 Chaincode package ID: $PACKAGE_ID"

# Approve chaincode for Org3
echo "✅ Approving chaincode for Org3..."
peer lifecycle chaincode approveformyorg -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --channelID certchannel \
  --name cert_cc \
  --version 1.0 \
  --package-id "$PACKAGE_ID" \
  --sequence 1 \
  --tls \
  --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

if [ $? -ne 0 ]; then
  echo "⚠️  Warning: Approval may have failed. This might be because the chaincode is already approved."
else
  echo "✅ Chaincode approved for Org3 successfully!"
fi

# Verify Org3 connection profile
echo "🔍 Checking Org3 connection profile..."
if [ ! -f "${PWD}/organizations/peerOrganizations/org3.example.com/connection-org3.json" ]; then
  echo "⚠️  Warning: Org3 connection profile not found. Generating it now..."
  
  # Run the connection profile generator script
  cd addOrg3
  ./ccp-generate.sh
  cd ..
  
  if [ ! -f "${PWD}/organizations/peerOrganizations/org3.example.com/connection-org3.json" ]; then
    echo "❌ Error: Failed to generate Org3 connection profile"
    exit 1
  fi
  
  echo "✅ Successfully generated Org3 connection profile!"
else
  echo "✅ Org3 connection profile exists!"
fi

# Setup Org3 wallet in the certificate-management-ui
cd ../certificate-management-ui

if [ ! -d "./wallet/org3" ]; then
  echo "📝 Setting up Org3 wallet..."
  node setupWallet.js
  
  if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to set up wallet"
    exit 1
  fi
else
  echo "✅ Org3 wallet already exists!"
fi

echo "🎉 Setup complete! You can now access the Certificate Management UI as a Verifier."
echo "   Run: npm run dev"
echo "   Then visit: http://localhost:3000"