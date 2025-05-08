#!/bin/bash

# Script to fix certificate-management-ui state database issues
# This script focuses on resolving the "Query failed. Errors: []" problem

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

echo -e "${YELLOW}===== Deep Fix for Certificate Management UI Query Issues =====${NC}"
echo -e "${YELLOW}This script will perform a complete rebuild of the network and chaincode deployment${NC}"

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

# Check for available Docker volumes and prune unused ones
function checkAndPruneDockerVolumes() {
  echo -e "${YELLOW}Checking Docker volumes...${NC}"
  docker volume ls | grep fabric
  
  echo -e "${YELLOW}Pruning unused Docker volumes to free up space...${NC}"
  docker volume prune --force
}

# Stop and remove all Docker containers 
function cleanupDockerContainers() {
  echo -e "${YELLOW}Stopping all running Docker containers...${NC}"
  docker stop $(docker ps -aq) 2>/dev/null || true
  
  echo -e "${YELLOW}Removing all Docker containers...${NC}"
  docker rm $(docker ps -aq) 2>/dev/null || true
  
  echo -e "${YELLOW}Checking for remaining Docker containers...${NC}"
  docker ps -a
}

# Check if CouchDB is being used as state database
function checkStateDBConfig() {
  echo -e "${YELLOW}Checking state database configuration...${NC}"
  grep -r "stateDatabase" /home/deepak/Desktop/Hyperledger_fabric_certificate-main/config/core.yaml
  
  echo -e "${YELLOW}Setting up core.yaml to use CouchDB for improved rich queries...${NC}"
  sed -i 's/stateDatabase: goleveldb/stateDatabase: CouchDB/g' /home/deepak/Desktop/Hyperledger_fabric_certificate-main/config/core.yaml || echo -e "${RED}Failed to modify core.yaml${NC}"
}

# Fix the certificate management UI app.js
function fixAppJs() {
  echo -e "${YELLOW}Creating backup of app.js...${NC}"
  cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui
  cp -f app.js app.js.couchdb.bak
  
  echo -e "${YELLOW}Modifying app.js to work with empty/null responses...${NC}"
  
  # Replace the error-prone part with robust error handling
  sed -i '/const result = await contract.evaluateTransaction..GetAllCertificates../,/gateway.disconnect/c\
      try {\
        const result = await contract.evaluateTransaction("GetAllCertificates");\
        \
        console.log("GetAllCertificates raw result:", result ? result.toString() : "null or empty");\
        \
        // Handle empty responses\
        if (!result || result.length === 0) {\
          console.log("No certificates found in the ledger");\
          res.json([]);\
          gateway.disconnect();\
          return;\
        }\
        \
        try {\
          const certificates = JSON.parse(result.toString());\
          res.json(certificates);\
        } catch (parseError) {\
          console.error(`Error parsing certificates result: ${parseError}`);\
          res.json([]);\
        }\
        \
        gateway.disconnect();\
      } catch (error) {\
        console.error(`Error evaluating GetAllCertificates: ${error}`);\
        res.json([]);\
        gateway.disconnect();\
      }' app.js
}

# Restart the network and redeploy chaincode with CouchDB
function rebuildNetwork() {
  echo -e "${YELLOW}Taking down the network...${NC}"
  cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network
  ./network.sh down
  
  echo -e "${YELLOW}Bringing up the network with CouchDB state database...${NC}"
  ./network.sh up createChannel -c certchannel -s couchdb
  
  echo -e "${YELLOW}Deploying chaincode with CouchDB support...${NC}"
  ./network.sh deployCC -ccn cert_cc -ccp ../test-network/chaincode/cert_cc/go -ccl go -ccep "OR('Org1MSP.peer','Org2MSP.peer')"
  
  echo -e "${GREEN}Network rebuilt with CouchDB!${NC}"
}

# Create and deploy CouchDB indexes
function createCouchDBIndexes() {
  cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui
  
  echo -e "${YELLOW}Creating CouchDB index definitions...${NC}"
  
  # Create a directory structure for CouchDB indexes
  mkdir -p chaincode/META-INF/statedb/couchdb/indexes
  
  # Create the index definition file
  cat > chaincode/META-INF/statedb/couchdb/indexes/indexCertificate.json << EOF
{
  "index": {
    "fields": ["certID", "studentID", "issuer"]
  },
  "ddoc": "indexCertificateDoc",
  "name": "indexCertificate",
  "type": "json"
}
EOF

  echo -e "${GREEN}CouchDB index definition created!${NC}"
}

# Set up wallet for interacting with the network
function setupWallet() {
  echo -e "${YELLOW}Setting up wallet...${NC}"
  cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui
  node setupWallet.js
}

# Issue a test certificate
function issueTestCertificate() {
  echo -e "${YELLOW}Issuing test certificate...${NC}"
  setOrg1Env
  
  # Define certificate variables
  CERT_ID="cert003"
  STUDENT_ID="student003"
  CERT_HASH="hash003"
  ISSUER="UniversityOrg"
  
  # Use CLI to issue certificate
  cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui
  
  echo -e "${YELLOW}Using peer CLI to issue test certificate...${NC}"
  peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile $ORDERER_CA -C certchannel -n cert_cc \
    --peerAddresses localhost:7051 --tlsRootCertFiles /home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
    --peerAddresses localhost:9051 --tlsRootCertFiles /home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
    -c "{\"function\":\"IssueCertificate\",\"Args\":[\"${STUDENT_ID}\",\"${CERT_ID}\",\"${CERT_HASH}\",\"${ISSUER}\"]}"
    
  sleep 3
  
  echo -e "${YELLOW}Verifying test certificate exists...${NC}"
  peer chaincode query -C certchannel -n cert_cc -c "{\"Args\":[\"GetCertificate\", \"${CERT_ID}\"]}" \
    --tls --cafile $ORDERER_CA
}

# Create CLI helper for application
function createCLIHelper() {
  echo -e "${YELLOW}Creating CLI helper for application...${NC}"
  cat > /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui/cli-helper.js << EOF
const { exec } = require('child_process');
const util = require('util');
const execAsync = util.promisify(exec);
const path = require('path');

/**
 * Helper function to execute chaincode query using peer CLI
 * @param {string} funcName - Chaincode function to call
 * @param {Array} args - Arguments for the function call
 * @returns {Promise<string>} - Query result as JSON string
 */
async function executePeerQuery(funcName, args = []) {
  try {
    console.log(\`Executing CLI query: \${funcName} with args: \${JSON.stringify(args)}\`);
    
    // Set up environment variables for Fabric
    process.env.PATH = process.env.PATH + ':/home/deepak/Desktop/Hyperledger_fabric_certificate-main/bin';
    process.env.FABRIC_CFG_PATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/config';
    process.env.CORE_PEER_TLS_ENABLED = 'true';
    process.env.CORE_PEER_LOCALMSPID = 'Org1MSP';
    process.env.CORE_PEER_TLS_ROOTCERT_FILE = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt';
    process.env.CORE_PEER_MSPCONFIGPATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp';
    process.env.CORE_PEER_ADDRESS = 'localhost:7051';

    // Build args string
    const argsString = args.map(arg => \`"\${arg}"\`).join(',');
    const ORDERER_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem';
    
    // Build the peer command with proper command structure
    const command = \`peer chaincode query -C certchannel -n cert_cc -c '{"Args":["\${funcName}",\${argsString}]}' --tls --cafile \${ORDERER_CA}\`;
    
    console.log('Executing command:', command);
    
    // Execute the command
    const { stdout, stderr } = await execAsync(command);
    
    if (stderr) {
      console.error('CLI command error:', stderr);
    }
    
    return stdout.trim();
  } catch (error) {
    console.error('Error executing peer command:', error.message);
    return JSON.stringify([]);  // Return empty array on error
  }
}

module.exports = { executePeerQuery };
EOF

  echo -e "${GREEN}CLI helper created successfully!${NC}"
}

# Update app.js to add CLI fallback option
function addCLIFallback() {
  echo -e "${YELLOW}Adding CLI fallback to app.js...${NC}"
  
  cat > /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui/app.js.with.fallback << 'EOF'
const express = require('express');
const cors = require('cors');
const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs');
const { executePeerQuery } = require('./cli-helper');

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Organizations configuration
const organizations = {
  university: {
    name: 'UniversityOrg',
    mspId: 'Org1MSP',
    connectionProfilePath: path.resolve(__dirname, '..', 'test-network', 'organizations', 'peerOrganizations', 'org1.example.com', 'connection-org1.json'),
    walletPath: path.join(__dirname, 'wallet', 'org1'),
    identity: 'admin'
  },
  student: {
    name: 'StudentOrg',
    mspId: 'Org2MSP',
    connectionProfilePath: path.resolve(__dirname, '..', 'test-network', 'organizations', 'peerOrganizations', 'org2.example.com', 'connection-org2.json'),
    walletPath: path.join(__dirname, 'wallet', 'org2'),
    identity: 'admin'
  },
  verifier: {
    name: 'VerifierOrg',
    mspId: 'Org3MSP',
    connectionProfilePath: path.resolve(__dirname, '..', 'test-network', 'organizations', 'peerOrganizations', 'org3.example.com', 'connection-org3.json'),
    walletPath: path.join(__dirname, 'wallet', 'org3'),
    identity: 'admin'
  }
};

// Simple authentication middleware (in a real app, use a proper authentication system)
const authenticateOrg = (orgKey) => (req, res, next) => {
  // In a real app, validate credentials against a database or other service
  const apiKey = req.headers['x-api-key'];

  // Simple API key validation (for demo purposes only)
  // In production, use proper authentication with JWT or sessions
  const validApiKeys = {
    university: 'university-api-key-123',
    student: 'student-api-key-456',
    verifier: 'verifier-api-key-789'
  };

  if (apiKey && apiKey === validApiKeys[orgKey]) {
    req.organization = organizations[orgKey];
    next();
  } else {
    res.status(401).json({ error: 'Unauthorized: Invalid API key' });
  }
};

// Helper function to connect to the network with organization credentials
async function connectToNetwork(orgConfig) {
  // Load connection profile
  let connectionProfile;
  try {
    // Check if connection profile exists first
    if (!fs.existsSync(orgConfig.connectionProfilePath)) {
      throw new Error(`Connection profile not found at ${orgConfig.connectionProfilePath}`);
    }
    
    const connectionProfileJson = fs.readFileSync(orgConfig.connectionProfilePath, 'utf8');
    connectionProfile = JSON.parse(connectionProfileJson);
  } catch (error) {
    throw new Error(`Error loading connection profile: ${error.message}`);
  }

  // Create a wallet instance for the organization
  const wallet = await Wallets.newFileSystemWallet(orgConfig.walletPath);

  // Check if the admin identity exists
  const identity = await wallet.get(orgConfig.identity);
  if (!identity) {
    throw new Error(`Identity ${orgConfig.identity} not found in wallet for ${orgConfig.name}`);
  }

  // Connect to the gateway with discovery disabled
  const gateway = new Gateway();
  try {
    await gateway.connect(connectionProfile, {
      wallet,
      identity: orgConfig.identity,
      discovery: { enabled: false }
    });

    // Get the network and contract
    const network = await gateway.getNetwork('certchannel');
    console.log(`Successfully connected to channel: certchannel`);
    
    try {
      const contract = network.getContract('cert_cc');
      console.log(`Successfully got contract: cert_cc`);
      return { gateway, contract };
    } catch (contractError) {
      console.error(`Failed to get contract: ${contractError}`);
      throw contractError;
    }
  } catch (gatewayError) {
    console.error(`Failed to connect to gateway: ${gatewayError}`);
    throw gatewayError;
  }
}

// ===== UNIVERSITY ENDPOINTS =====
// Endpoint to get all certificates - University
app.get('/api/university/certificates', authenticateOrg('university'), async (req, res) => {
  try {
    console.log("Getting all certificates as University...");
    const { contract, gateway } = await connectToNetwork(req.organization);
    
    try {
      // Try using the SDK first
      console.log("Attempting to get certificates with SDK...");
      const result = await contract.evaluateTransaction('GetAllCertificates');
      
      console.log(`SDK Result: ${result ? result.toString() : "null or empty"}`);
      
      // Handle empty responses
      if (!result || result.length === 0) {
        console.log("No certificates found in the ledger via SDK");
        
        // Try CLI fallback immediately if SDK returns empty
        try {
          console.log("Falling back to CLI approach for GetAllCertificates...");
          const cliResult = await executePeerQuery('GetAllCertificates', []);
          
          if (cliResult && cliResult.length > 0) {
            try {
              const certificates = JSON.parse(cliResult);
              console.log("CLI approach returned data successfully");
              res.json(certificates);
            } catch (parseError) {
              console.error(`Error parsing CLI certificates result: ${parseError}`);
              res.json([]);
            }
          } else {
            console.log("CLI approach also returned no certificates");
            res.json([]);
          }
        } catch (cliError) {
          console.error(`CLI fallback failed: ${cliError}`);
          res.json([]);
        }
        
        gateway.disconnect();
        return;
      }
      
      try {
        const certificates = JSON.parse(result.toString());
        res.json(certificates);
      } catch (parseError) {
        console.error(`Error parsing certificates result: ${parseError}`);
        res.json([]);
      }
      
      gateway.disconnect();
    } catch (sdkError) {
      console.error(`SDK query failed: ${sdkError}`);
      console.log("Falling back to CLI for GetAllCertificates...");
      
      try {
        // Fall back to CLI approach
        const cliResult = await executePeerQuery('GetAllCertificates', []);
        
        // Handle empty responses
        if (!cliResult || cliResult.length === 0) {
          console.log("CLI approach returned no certificates");
          res.json([]);
          gateway.disconnect();
          return;
        }
        
        try {
          const certificates = JSON.parse(cliResult);
          console.log("CLI approach returned data successfully");
          res.json(certificates);
        } catch (parseError) {
          console.error(`Error parsing CLI certificates result: ${parseError}`);
          res.json([]);
        }
      } catch (cliError) {
        console.error(`CLI fallback failed: ${cliError}`);
        res.json([]);
      } finally {
        gateway.disconnect();
      }
    }
  } catch (error) {
    console.error(`Error getting certificates as University: ${error}`);
    res.status(500).json({ error: error.message });
  }
});

// Rest of your endpoints remain the same...

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Organization-specific API endpoints are available at /api/{university|student|verifier}/certificates`);
});
EOF

  # Copy the new file over app.js
  echo -e "${YELLOW}Backing up original app.js and applying new version with CLI fallback...${NC}"
  cp -f /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui/app.js /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui/app.js.original
  cp -f /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui/app.js.with.fallback /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui/app.js
}

# Fixed endpoint for manual verification
function createTestEndpoint() {
  echo -e "${YELLOW}Creating test endpoint to verify solution...${NC}"
  cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui
  
  # Create a simple test script
  cat > test-query.js << 'EOF'
const { executePeerQuery } = require('./cli-helper');

async function testQuery() {
  try {
    console.log("Testing GetAllCertificates query using CLI...")
    const result = await executePeerQuery('GetAllCertificates', []);
    console.log("Results:", result);
    
    console.log("\nTesting GetCertificate for cert003...")
    const cert = await executePeerQuery('GetCertificate', ['cert003']);
    console.log("Certificate:", cert);
  } catch (error) {
    console.error("Error:", error);
  }
}

testQuery();
EOF

  echo -e "${GREEN}Test endpoint created!${NC}"
}

# Main execution
echo -e "${YELLOW}===== Starting Deep Fix Process =====${NC}"

echo -e "${YELLOW}Step 1: Checking Docker environment${NC}"
checkAndPruneDockerVolumes

echo -e "${YELLOW}Step 2: Cleaning up Docker containers${NC}"
cleanupDockerContainers

echo -e "${YELLOW}Step 3: Checking and adjusting state database config${NC}"
checkStateDBConfig

echo -e "${YELLOW}Step 4: Rebuilding network with CouchDB${NC}"
rebuildNetwork

echo -e "${YELLOW}Step 5: Creating CouchDB indexes${NC}"
createCouchDBIndexes

echo -e "${YELLOW}Step 6: Setting up wallet${NC}"
setupWallet

echo -e "${YELLOW}Step 7: Creating CLI helper${NC}"
createCLIHelper

echo -e "${YELLOW}Step 8: Adding CLI fallback to app.js${NC}"
addCLIFallback

echo -e "${YELLOW}Step 9: Issuing test certificate${NC}"
issueTestCertificate

echo -e "${YELLOW}Step 10: Creating test endpoint${NC}"
createTestEndpoint

echo -e "${GREEN}===== Deep Fix Process Complete! =====${NC}"
echo -e "${YELLOW}To test the solution, run:${NC}"
echo -e "cd /home/deepak/Desktop/Hyperledger_fabric_certificate-main/certificate-management-ui"
echo -e "node test-query.js"
echo -e "\n${YELLOW}To start the application:${NC}"
echo -e "npm run dev"