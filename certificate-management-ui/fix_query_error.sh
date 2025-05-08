#!/bin/bash

# Script to fix the "Query failed. Errors: []" issue in certificate management UI
# This script modifies the app.js file to handle the issue by implementing a fallback mechanism

# Set environment variables for Fabric
export PATH=$PATH:/home/deepak/Desktop/Hyperledger_fabric_certificate-main/bin
export FABRIC_CFG_PATH=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/config
export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Color coding for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}===== Fixing Query Failed Error for Certificate Management UI =====${NC}"

# Backup original app.js
echo -e "${YELLOW}Creating backup of app.js...${NC}"
cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui
cp app.js app.js.bak
echo -e "${GREEN}Backup created: app.js.bak${NC}"

# Set organization 1 environment (University)
function setOrg1Env() {
  export CORE_PEER_LOCALMSPID="Org1MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
  export CORE_PEER_ADDRESS=localhost:7051
  echo -e "${YELLOW}Environment set for Org1 (University)${NC}"
}

# Create a helper script to get certificates using peer CLI
echo -e "${YELLOW}Creating helper script to use peer CLI for queries...${NC}"
cat > cli-helper.js << EOF
const { exec } = require('child_process');
const util = require('util');
const execAsync = util.promisify(exec);

/**
 * Helper function to execute chaincode query using peer CLI
 * @param {string} funcName - Chaincode function to call
 * @param {Array} args - Arguments for the function call
 * @returns {Promise<string>} - Query result as JSON string
 */
async function executePeerQuery(funcName, args = []) {
  try {
    // Set up environment variables
    process.env.PATH = process.env.PATH + ':/home/deepak/Desktop/Hyperledger_fabric_certificate-main/bin';
    process.env.FABRIC_CFG_PATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/config';
    process.env.CORE_PEER_TLS_ENABLED = 'true';
    process.env.CORE_PEER_LOCALMSPID = 'Org1MSP';
    process.env.CORE_PEER_TLS_ROOTCERT_FILE = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt';
    process.env.CORE_PEER_MSPCONFIGPATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp';
    process.env.CORE_PEER_ADDRESS = 'localhost:7051';

    // Build args string
    const argsString = args.map(arg => `"${arg}"`).join(',');
    
    // Build the peer command
    const ORDERER_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem';
    const command = `peer chaincode query -C certchannel -n cert_cc -c '{"function":"${funcName}","Args":[${argsString}]}' --tls --cafile ${ORDERER_CA}`;
    
    console.log('Executing command:', command);
    
    // Execute the command
    const { stdout, stderr } = await execAsync(command);
    
    if (stderr) {
      console.error('CLI command error:', stderr);
    }
    
    return stdout.trim();
  } catch (error) {
    console.error('Error executing peer command:', error.message);
    throw error;
  }
}

module.exports = { executePeerQuery };
EOF

echo -e "${GREEN}Helper script created: cli-helper.js${NC}"

# Modify app.js to add CLI fallback when SDK calls fail
echo -e "${YELLOW}Updating app.js to add CLI fallback for failing queries...${NC}"

# Use sed to replace the University GetAllCertificates endpoint handler with our enhanced version
sed -i '
/app.get..\\/api\\/university\\/certificates., authenticateOrg..university.., async .req, res. => {/,/})/c\
// ===== UNIVERSITY ENDPOINTS =====\
// Endpoint to get all certificates - University\
app.get(\x27/api/university/certificates\x27, authenticateOrg(\x27university\x27), async (req, res) => {\
  try {\
    console.log("Getting all certificates as University...");\
    const { contract, gateway } = await connectToNetwork(req.organization);\
    \
    try {\
      console.log("Attempting to get certificates with SDK...");\
      const result = await contract.evaluateTransaction(\x27GetAllCertificates\x27);\
      \
      // Handle empty responses\
      if (!result || result.length === 0) {\
        res.json([]);  // Return empty array if no certificates\
        gateway.disconnect();\
        return;\
      }\
      \
      try {\
        const certificates = JSON.parse(result.toString());\
        res.json(certificates);\
      } catch (parseError) {\
        console.error(`Error parsing certificates result: ${parseError}`);\
        res.json([]);  // Return empty array if parsing fails\
      }\
      \
      gateway.disconnect();\
    } catch (sdkError) {\
      console.error(`SDK query failed: ${sdkError}`);\
      console.log("Falling back to CLI for GetAllCertificates...");\
      \
      try {\
        // Fall back to CLI approach\
        const { executePeerQuery } = require(\x27./cli-helper\x27);\
        const cliResult = await executePeerQuery(\x27GetAllCertificates\x27, []);\
        \
        // Handle empty responses\
        if (!cliResult || cliResult.length === 0) {\
          res.json([]);\
          gateway.disconnect();\
          return;\
        }\
        \
        try {\
          const certificates = JSON.parse(cliResult);\
          res.json(certificates);\
        } catch (parseError) {\
          console.error(`Error parsing CLI certificates result: ${parseError}`);\
          res.json([]);\
        }\
      } catch (cliError) {\
        console.error(`CLI fallback failed: ${cliError}`);\
        res.status(500).json({ error: "Both SDK and CLI approaches failed to get certificates" });\
      } finally {\
        gateway.disconnect();\
      }\
    }\
  } catch (error) {\
    console.error(`Error getting certificates as University: ${error}`);\
    res.status(500).json({ error: error.message });\
  }\
});
' app.js

# Now do the same for the Student endpoint
sed -i '
/app.get..\\/api\\/student\\/certificates., authenticateOrg..student.., async .req, res. => {/,/})/c\
// Endpoint to get all certificates - Student\
app.get(\x27/api/student/certificates\x27, authenticateOrg(\x27student\x27), async (req, res) => {\
  try {\
    console.log("Getting all certificates as Student...");\
    const { contract, gateway } = await connectToNetwork(req.organization);\
    \
    try {\
      console.log("Attempting to get certificates with SDK...");\
      const result = await contract.evaluateTransaction(\x27GetAllCertificates\x27);\
      \
      // Handle empty responses\
      if (!result || result.length === 0) {\
        res.json([]);  // Return empty array if no certificates\
        gateway.disconnect();\
        return;\
      }\
      \
      try {\
        const certificates = JSON.parse(result.toString());\
        res.json(certificates);\
      } catch (parseError) {\
        console.error(`Error parsing certificates result: ${parseError}`);\
        res.json([]);  // Return empty array if parsing fails\
      }\
      \
      gateway.disconnect();\
    } catch (sdkError) {\
      console.error(`SDK query failed: ${sdkError}`);\
      console.log("Falling back to CLI for GetAllCertificates...");\
      \
      try {\
        // Fall back to CLI approach\
        const { executePeerQuery } = require(\x27./cli-helper\x27);\
        const cliResult = await executePeerQuery(\x27GetAllCertificates\x27, []);\
        \
        // Handle empty responses\
        if (!cliResult || cliResult.length === 0) {\
          res.json([]);\
          gateway.disconnect();\
          return;\
        }\
        \
        try {\
          const certificates = JSON.parse(cliResult);\
          res.json(certificates);\
        } catch (parseError) {\
          console.error(`Error parsing CLI certificates result: ${parseError}`);\
          res.json([]);\
        }\
      } catch (cliError) {\
        console.error(`CLI fallback failed: ${cliError}`);\
        res.status(500).json({ error: "Both SDK and CLI approaches failed to get certificates" });\
      } finally {\
        gateway.disconnect();\
      }\
    }\
  } catch (error) {\
    console.error(`Error getting certificates as Student: ${error}`);\
    res.status(500).json({ error: error.message });\
  }\
});
' app.js

# Create a test certificate using CLI for testing
echo -e "${YELLOW}Creating test certificate using CLI for testing...${NC}"
setOrg1Env

# Issue test certificate
echo -e "${YELLOW}Issuing test certificate...${NC}"
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile $ORDERER_CA -C certchannel -n cert_cc \
  --peerAddresses localhost:7051 --tlsRootCertFiles /home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 --tlsRootCertFiles /home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"IssueCertificate","Args":["student002","cert002","hash002","UniversityOrg"]}' \
  --waitForEvent
sleep 5

# Query certificate to verify it was created
echo -e "${YELLOW}Verifying test certificate was created...${NC}"
peer chaincode query -C certchannel -n cert_cc -c '{"Args":["GetCertificate", "cert002"]}' --tls --cafile $ORDERER_CA

echo -e "${GREEN}===== Fix completed! =====${NC}"
echo -e "${YELLOW}Restart your application with: npm run dev${NC}"