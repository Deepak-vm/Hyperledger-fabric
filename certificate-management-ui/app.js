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

// Endpoint to issue a new certificate - University
app.post('/api/university/certificates', authenticateOrg('university'), async (req, res) => {
  try {
    console.log("Issuing new certificate as University...");
    const { studentID, certID, certHash, issuer } = req.body;

    // Validate required fields
    if (!studentID || !certID || !certHash) {
      return res.status(400).json({ error: 'Missing required fields: studentID, certID, and certHash are required' });
    }

    // Default issuer to UniversityOrg if not provided
    const certificateIssuer = issuer || 'UniversityOrg';

    // Connect to the network
    const { gateway } = await connectToNetwork(req.organization);

    try {
      // Use the CLI approach directly since SDK approach has issues
      console.log("Using CLI for issuing certificate...");

      // Set up environment variables for executing command
      const { exec } = require('child_process');
      const util = require('util');
      const execAsync = util.promisify(exec);

      const ORDERER_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem';
      const ORG1_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt';
      const ORG2_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt';

      // Set environment variables for Fabric
      process.env.PATH = process.env.PATH + ':/home/deepak/Desktop/Hyperledger_fabric_certificate-main/bin';
      process.env.FABRIC_CFG_PATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/config';
      process.env.CORE_PEER_TLS_ENABLED = 'true';
      process.env.CORE_PEER_LOCALMSPID = 'Org1MSP';
      process.env.CORE_PEER_TLS_ROOTCERT_FILE = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt';
      process.env.CORE_PEER_MSPCONFIGPATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp';
      process.env.CORE_PEER_ADDRESS = 'localhost:7051';

      // Build the command for issuing a certificate
      const command = `peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile ${ORDERER_CA} -C certchannel -n cert_cc \
        --peerAddresses localhost:7051 --tlsRootCertFiles ${ORG1_CA} \
        --peerAddresses localhost:9051 --tlsRootCertFiles ${ORG2_CA} \
        -c '{"function":"IssueCertificate","Args":["${studentID}","${certID}","${certHash}","${certificateIssuer}"]}'`;

      console.log("Executing command:", command);

      // Execute the command
      const { stdout, stderr } = await execAsync(command);

      if (stderr && !stderr.includes('status:200')) {
        console.error("Command error:", stderr);

        if (stderr.includes('already exists')) {
          return res.status(409).json({ error: `Certificate ${certID} already exists` });
        }

        throw new Error(stderr);
      }

      console.log("Command output:", stdout);

      // Wait for transaction to be committed
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Return success response
      res.status(201).json({
        message: 'Certificate issued successfully',
        certificate: {
          studentID,
          certID,
          certHash,
          issuer: certificateIssuer
        }
      });
    } catch (error) {
      console.error(`Error issuing certificate: ${error}`);
      res.status(500).json({ error: error.message });
    } finally {
      // Disconnect from the gateway
      gateway.disconnect();
    }
  } catch (error) {
    console.error(`Error connecting to network: ${error}`);
    res.status(500).json({ error: error.message });
  }
});

// Endpoint to get a specific certificate - University
app.get('/api/university/certificates/:id', authenticateOrg('university'), async (req, res) => {
  try {
    console.log(`Getting certificate ${req.params.id} as University...`);
    const { gateway } = await connectToNetwork(req.organization);

    try {
      // Use the CLI approach directly
      console.log("Using CLI for getting certificate details...");

      const certID = req.params.id;
      const result = await executePeerQuery('GetCertificate', [certID]);

      if (!result || result.length === 0 || result.includes('does not exist')) {
        res.status(404).json({ error: `Certificate ${certID} not found` });
        gateway.disconnect();
        return;
      }

      try {
        const certificate = JSON.parse(result);
        res.json(certificate);
      } catch (parseError) {
        console.error(`Error parsing certificate result: ${parseError}`);
        res.status(500).json({ error: 'Failed to parse certificate data' });
      }
    } catch (error) {
      console.error(`Error getting certificate details: ${error}`);
      res.status(500).json({ error: error.message });
    } finally {
      gateway.disconnect();
    }
  } catch (error) {
    console.error(`Error connecting to network: ${error}`);
    res.status(500).json({ error: error.message });
  }
});

// Endpoint to verify a certificate - University
app.get('/api/university/certificates/verify/:id', authenticateOrg('university'), async (req, res) => {
  try {
    console.log(`Verifying certificate ${req.params.id} as University...`);
    const { gateway } = await connectToNetwork(req.organization);

    try {
      // Use the CLI approach directly
      console.log("Using CLI for verifying certificate...");

      const certID = req.params.id;
      const result = await executePeerQuery('VerifyCertificate', [certID]);

      const valid = result.toLowerCase().includes('true');
      res.json({ valid });
    } catch (error) {
      console.error(`Error verifying certificate: ${error}`);
      res.status(500).json({ error: error.message });
    } finally {
      gateway.disconnect();
    }
  } catch (error) {
    console.error(`Error connecting to network: ${error}`);
    res.status(500).json({ error: error.message });
  }
});

// Endpoint to revoke a certificate - University only
app.delete('/api/university/certificates/:id', authenticateOrg('university'), async (req, res) => {
  try {
    console.log(`Revoking certificate ${req.params.id} as University...`);
    const { gateway } = await connectToNetwork(req.organization);

    try {
      // Use the CLI approach directly
      console.log("Using CLI for revoking certificate...");

      const certID = req.params.id;

      // Set up environment variables for executing command
      const { exec } = require('child_process');
      const util = require('util');
      const execAsync = util.promisify(exec);

      const ORDERER_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem';
      const ORG1_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt';
      const ORG2_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt';

      // Set environment variables for Fabric
      process.env.PATH = process.env.PATH + ':/home/deepak/Desktop/Hyperledger_fabric_certificate-main/bin';
      process.env.FABRIC_CFG_PATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/config';
      process.env.CORE_PEER_TLS_ENABLED = 'true';
      process.env.CORE_PEER_LOCALMSPID = 'Org1MSP';
      process.env.CORE_PEER_TLS_ROOTCERT_FILE = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt';
      process.env.CORE_PEER_MSPCONFIGPATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp';
      process.env.CORE_PEER_ADDRESS = 'localhost:7051';

      // Build the command for revoking a certificate
      const command = `peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile ${ORDERER_CA} -C certchannel -n cert_cc \
        --peerAddresses localhost:7051 --tlsRootCertFiles ${ORG1_CA} \
        --peerAddresses localhost:9051 --tlsRootCertFiles ${ORG2_CA} \
        -c '{"function":"RevokeCertificate","Args":["${certID}"]}'`;

      console.log("Executing command:", command);

      // Execute the command
      const { stdout, stderr } = await execAsync(command);

      if (stderr && !stderr.includes('status:200')) {
        console.error("Command error:", stderr);

        if (stderr.includes('does not exist')) {
          return res.status(404).json({ error: `Certificate ${certID} not found` });
        }

        throw new Error(stderr);
      }

      console.log("Command output:", stdout || 'Command executed successfully');

      // Wait for transaction to be committed
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Return success response
      res.json({
        success: true,
        message: 'Certificate revoked successfully'
      });
    } catch (error) {
      console.error(`Error revoking certificate: ${error}`);
      res.status(500).json({ error: error.message });
    } finally {
      gateway.disconnect();
    }
  } catch (error) {
    console.error(`Error connecting to network: ${error}`);
    res.status(500).json({ error: error.message });
  }
});

// Repeat similar endpoints for student and verifier organizations
// ...

// Student endpoints for viewing certificates
app.get('/api/student/certificates', authenticateOrg('student'), async (req, res) => {
  try {
    console.log("Getting all certificates as Student...");
    const { contract, gateway } = await connectToNetwork(req.organization);

    try {
      console.log("Using CLI for getting all certificates...");
      const result = await executePeerQuery('GetAllCertificates', []);

      if (!result || result.length === 0) {
        console.log("No certificates found");
        res.json([]);
        gateway.disconnect();
        return;
      }

      try {
        const certificates = JSON.parse(result);
        console.log("Successfully retrieved certificates");
        res.json(certificates);
      } catch (parseError) {
        console.error(`Error parsing certificates result: ${parseError}`);
        res.status(500).json({ error: 'Failed to parse certificate data' });
      }
    } catch (error) {
      console.error(`Error getting certificates: ${error}`);
      res.status(500).json({ error: error.message });
    } finally {
      gateway.disconnect();
    }
  } catch (error) {
    console.error(`Error connecting to network: ${error}`);
    res.status(500).json({ error: error.message });
  }
});

// Student endpoint for verifying a certificate - MUST be defined BEFORE the specific certificate route
app.get('/api/student/certificates/verify/:id', authenticateOrg('student'), async (req, res) => {
  try {
    console.log(`Verifying certificate ${req.params.id} as Student...`);
    const { gateway } = await connectToNetwork(req.organization);

    try {
      // Use the CLI approach directly
      console.log("Using CLI for verifying certificate...");

      const certID = req.params.id;
      const result = await executePeerQuery('VerifyCertificate', [certID]);

      const valid = result.toLowerCase().includes('true');
      res.json({ valid });
    } catch (error) {
      console.error(`Error verifying certificate: ${error}`);
      res.status(500).json({ error: error.message });
    } finally {
      gateway.disconnect();
    }
  } catch (error) {
    console.error(`Error connecting to network: ${error}`);
    res.status(500).json({ error: error.message });
  }
});

// Student endpoint for getting a specific certificate
app.get('/api/student/certificates/:id', authenticateOrg('student'), async (req, res) => {
  try {
    console.log(`Getting certificate ${req.params.id} as Student...`);
    const { gateway } = await connectToNetwork(req.organization);

    try {
      // Use the CLI approach directly
      console.log("Using CLI for getting certificate details...");

      const certID = req.params.id;
      const result = await executePeerQuery('GetCertificate', [certID]);

      if (!result || result.length === 0 || result.includes('does not exist')) {
        res.status(404).json({ error: `Certificate ${certID} not found` });
        gateway.disconnect();
        return;
      }

      try {
        const certificate = JSON.parse(result);
        res.json(certificate);
      } catch (parseError) {
        console.error(`Error parsing certificate result: ${parseError}`);
        res.status(500).json({ error: 'Failed to parse certificate data' });
      }
    } catch (error) {
      console.error(`Error getting certificate details: ${error}`);
      res.status(500).json({ error: error.message });
    } finally {
      gateway.disconnect();
    }
  } catch (error) {
    console.error(`Error connecting to network: ${error}`);
    res.status(500).json({ error: error.message });
  }
});

// Verifier endpoints
app.get('/api/verifier/certificates', authenticateOrg('verifier'), async (req, res) => {
  try {
    console.log("Getting all certificates as Verifier...");
    const { contract, gateway } = await connectToNetwork(req.organization);

    try {
      console.log("Using CLI for getting all certificates...");
      const result = await executePeerQuery('GetAllCertificates', []);

      if (!result || result.length === 0) {
        console.log("No certificates found");
        res.json([]);
        gateway.disconnect();
        return;
      }

      try {
        const certificates = JSON.parse(result);
        console.log("Successfully retrieved certificates");
        res.json(certificates);
      } catch (parseError) {
        console.error(`Error parsing certificates result: ${parseError}`);
        res.status(500).json({ error: 'Failed to parse certificate data' });
      }
    } catch (error) {
      console.error(`Error getting certificates: ${error}`);
      res.status(500).json({ error: error.message });
    } finally {
      gateway.disconnect();
    }
  } catch (error) {
    console.error(`Error connecting to network: ${error}`);
    res.status(500).json({ error: error.message });
  }
});

// Verifier endpoint for verifying a certificate
app.get('/api/verifier/certificates/verify/:id', authenticateOrg('verifier'), async (req, res) => {
  try {
    console.log(`Verifying certificate ${req.params.id} as Verifier...`);
    const { gateway } = await connectToNetwork(req.organization);

    try {
      // Use the CLI approach directly
      console.log("Using CLI for verifying certificate...");

      const certID = req.params.id;
      const result = await executePeerQuery('VerifyCertificate', [certID]);

      const valid = result.toLowerCase().includes('true');
      res.json({ valid });
    } catch (error) {
      console.error(`Error verifying certificate: ${error}`);
      res.status(500).json({ error: error.message });
    } finally {
      gateway.disconnect();
    }
  } catch (error) {
    console.error(`Error connecting to network: ${error}`);
    res.status(500).json({ error: error.message });
  }
});

// Verifier endpoint for getting a specific certificate
app.get('/api/verifier/certificates/:id', authenticateOrg('verifier'), async (req, res) => {
  try {
    console.log(`Getting certificate ${req.params.id} as Verifier...`);
    const { gateway } = await connectToNetwork(req.organization);

    try {
      // Use the CLI approach directly
      console.log("Using CLI for getting certificate details...");

      const certID = req.params.id;
      const result = await executePeerQuery('GetCertificate', [certID]);

      if (!result || result.length === 0 || result.includes('does not exist')) {
        res.status(404).json({ error: `Certificate ${certID} not found` });
        gateway.disconnect();
        return;
      }

      try {
        const certificate = JSON.parse(result);
        res.json(certificate);
      } catch (parseError) {
        console.error(`Error parsing certificate result: ${parseError}`);
        res.status(500).json({ error: 'Failed to parse certificate data' });
      }
    } catch (error) {
      console.error(`Error getting certificate details: ${error}`);
      res.status(500).json({ error: error.message });
    } finally {
      gateway.disconnect();
    }
  } catch (error) {
    console.error(`Error connecting to network: ${error}`);
    res.status(500).json({ error: error.message });
  }
});

// Rest of your endpoints remain the same...

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Organization-specific API endpoints are available at /api/{university|student|verifier}/certificates`);
});
