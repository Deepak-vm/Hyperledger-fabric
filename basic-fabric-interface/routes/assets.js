const express = require('express');
const { connectToNetwork, channelName, chaincodeName } = require('../utils/fabric');
const { exec } = require('child_process');
const path = require('path');

const router = express.Router();

// Helper function to execute a peer chaincode query command
function executePeerCommand(functionName, args = []) {
  return new Promise((resolve, reject) => {
    const testNetworkPath = process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network');
    const configPath = path.resolve(testNetworkPath, '../config/');
    const argsString = args.length > 0 ? `,"Args":[${args.map(arg => `"${arg}"`).join(',')}]` : `,"Args":[]`;

    // Set up the environment variables needed by the peer command
    const command = `cd ${testNetworkPath} && export FABRIC_CFG_PATH=${configPath} && 
      export CORE_PEER_TLS_ENABLED=true && 
      export CORE_PEER_LOCALMSPID="Org1MSP" && 
      export CORE_PEER_TLS_ROOTCERT_FILE=${testNetworkPath}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt && 
      export CORE_PEER_MSPCONFIGPATH=${testNetworkPath}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp && 
      export CORE_PEER_ADDRESS=localhost:7051 &&
      peer chaincode query -C ${channelName} -n ${chaincodeName} -c '{"function":"${functionName}"${argsString}}'`;

    console.log(`Executing command: ${command}`);

    exec(command, (error, stdout, stderr) => {
      if (error) {
        console.error(`Peer command error: ${error.message}`);
        return reject(error);
      }

      if (stderr) {
        console.error(`Peer command stderr: ${stderr}`);
      }

      console.log(`Peer command output: ${stdout}`);
      resolve(stdout);
    });
  });
}

// Get all certificates
router.get('/', async (req, res) => {
  try {
    console.log("Trying to get all certificates using peer CLI command...");

    try {
      // Try to use the peer CLI command first
      const result = await executePeerCommand('GetAllCertificates');
      console.log('Successfully retrieved certificates using peer CLI');

      let certificates;
      try {
        certificates = JSON.parse(result);
        console.log('Parsed certificates:', certificates);
        return res.json(certificates);
      } catch (e) {
        console.error('Error parsing certificates result:', e);
        return res.json({ rawData: result });
      }
    } catch (peerError) {
      console.error('Peer command failed, falling back to SDK:', peerError);

      // Fall back to SDK approach if peer command fails
      const { contract } = await connectToNetwork('admin');
      console.log(`Querying certificates using function: GetAllCertificates`);

      try {
        const result = await contract.evaluateTransaction('GetAllCertificates');
        console.log(`Successfully queried using function: GetAllCertificates`);

        let certificates = [];
        if (result && result.length > 0) {
          try {
            certificates = JSON.parse(result.toString());
            console.log('Parsed certificates:', certificates);
          } catch (e) {
            console.error('Error parsing certificates result:', e);
            return res.json({ rawData: result.toString() });
          }
        } else {
          console.log('No certificates found or empty result');
        }

        res.json(certificates);
      } catch (error) {
        console.error(`Function GetAllCertificates failed with error:`, error);
        res.status(500).json({
          error: 'Failed to query certificates',
          details: error?.message || 'Unknown error',
          chaincodeName,
          channelName
        });
      }
    }
  } catch (error) {
    console.error(`Failed to get certificates: ${error}`);
    res.status(500).json({
      error: error.message,
      chaincodeName,
      channelName
    });
  }
});

// Get a specific certificate by ID
router.get('/:id', async (req, res) => {
  try {
    const certId = req.params.id;

    // Validate certId
    if (!certId || certId === 'undefined') {
      return res.status(400).json({ error: 'Invalid certificate ID' });
    }

    try {
      // Try to use the peer CLI command first
      const result = await executePeerCommand('GetCertificate', [certId]);

      let certificate;
      try {
        certificate = JSON.parse(result);
        return res.json(certificate);
      } catch (e) {
        console.error('Error parsing certificate result:', e);
        return res.json({ rawData: result });
      }
    } catch (peerError) {
      console.error('Peer command failed, falling back to SDK:', peerError);

      // Fall back to SDK approach
      const { contract, gateway } = await connectToNetwork('admin');
      console.log(`Getting certificate ${certId} using GetCertificate function`);
      const result = await contract.evaluateTransaction('GetCertificate', certId);

      if (!result) {
        return res.status(404).json({ error: `Certificate ${certId} not found` });
      }

      let certificate;
      try {
        certificate = JSON.parse(result.toString());
      } catch (e) {
        console.error('Error parsing certificate result:', e);
        return res.json({ rawData: result.toString() });
      }

      await gateway.disconnect();
      res.json(certificate);
    }
  } catch (error) {
    console.error(`Failed to get certificate: ${error}`);

    if (error.message && (error.message.includes('does not exist') || error.message.includes('not found'))) {
      return res.status(404).json({ error: `Certificate ${req.params.id} not found` });
    }

    res.status(500).json({ error: error.message });
  }
});

// Verify a certificate
router.get('/:id/verify', async (req, res) => {
  try {
    const certId = req.params.id;

    // Validate certId
    if (!certId || certId === 'undefined') {
      return res.status(400).json({ error: 'Invalid certificate ID' });
    }

    try {
      // Try peer CLI command first
      const result = await executePeerCommand('VerifyCertificate', [certId]);
      // Simple check since the chaincode returns a boolean
      const isValid = result.trim() === 'true';
      return res.json({ valid: isValid });
    } catch (peerError) {
      console.error('Peer command failed for verification, falling back to SDK:', peerError);

      // Fall back to SDK approach
      const { contract, gateway } = await connectToNetwork('admin');

      // Try to verify the certificate
      console.log(`Verifying certificate ${certId}`);
      const result = await contract.evaluateTransaction('VerifyCertificate', certId);

      // Process the result - shouldn't try to parse as JSON, just check the string value
      const isValid = result.toString().trim() === 'true';

      // Disconnect from the gateway
      await gateway.disconnect();

      res.json({ valid: isValid });
    }
  } catch (error) {
    console.error(`Failed to verify certificate: ${error}`);

    // Check if certificate not found
    if (error.message && (error.message.includes('does not exist') || error.message.includes('not found'))) {
      return res.status(404).json({ error: `Certificate ${req.params.id} not found` });
    }

    res.status(500).json({ error: error.message });
  }
});

// Issue a new certificate
router.post('/', async (req, res) => {
  try {
    let { id, recipient, issuer, data } = req.body;

    // Trim whitespace from string inputs to prevent JSON parsing errors
    if (id) id = id.trim();
    if (recipient) recipient = recipient.trim();
    if (issuer) issuer = issuer.trim();

    // Validate required fields
    if (!id || !recipient || !issuer) {
      return res.status(400).json({ error: 'Missing required fields. Need id, recipient, and issuer.' });
    }

    // Generate a simple hash if not provided (in production, you'd use a proper hashing algorithm)
    // In a real-world scenario, this would be a cryptographic hash of the certificate data
    const certHash = data ? JSON.stringify(data).slice(0, 10) + Date.now().toString() : "hash" + Date.now().toString();

    // Set up retry parameters
    const MAX_RETRIES = 5;
    let retryCount = 0;
    let success = false;
    let lastError = null;

    // Retry loop to handle MVCC_READ_CONFLICT errors
    while (retryCount < MAX_RETRIES && !success) {
      try {
        // Build the peer command as a single line to avoid shell interpretation issues
        let command = `cd ${process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')} && `;
        command += `export FABRIC_CFG_PATH=${path.resolve((process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')), '../config/')} && `;
        command += `export CORE_PEER_TLS_ENABLED=true && `;
        command += `export CORE_PEER_LOCALMSPID="Org1MSP" && `;
        command += `export CORE_PEER_TLS_ROOTCERT_FILE=${process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt && `;
        command += `export CORE_PEER_MSPCONFIGPATH=${process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp && `;
        command += `export CORE_PEER_ADDRESS=localhost:7051 && `;

        // Construct the chaincode command with properly escaped JSON
        command += `peer chaincode invoke `;
        command += `-o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls `;
        command += `--cafile ${process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem `;
        command += `-C ${channelName} -n ${chaincodeName} `;
        command += `--peerAddresses localhost:7051 --tlsRootCertFiles ${process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt `;
        command += `--peerAddresses localhost:9051 --tlsRootCertFiles ${process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt `;

        // Now include all 4 required parameters (recipient, id, certHash, issuer)
        jsonArgs = `'{"function":"IssueCertificate","Args":["${recipient}","${id}","${certHash}","${issuer}"]}'`;
        command += `-c ${jsonArgs} --waitForEvent`;

        console.log(`Executing command: ${command}`);

        // Use promisify to convert the exec callback to a promise
        const util = require('util');
        const execPromise = util.promisify(exec);

        try {
          const { stdout, stderr } = await execPromise(command);

          if (stderr && stderr.includes('MVCC_READ_CONFLICT')) {
            console.log(`Attempt ${retryCount + 1}/${MAX_RETRIES} failed with MVCC_READ_CONFLICT. Retrying...`);
            retryCount++;
            // Add a small delay before retrying to allow other transactions to complete
            await new Promise(resolve => setTimeout(resolve, 1000 * retryCount));
            continue;
          } else if (stderr && !stderr.includes('Chaincode invoke successful')) {
            console.error(`Peer command stderr: ${stderr}`);
            lastError = new Error(stderr);
            break;
          }

          console.log(`Certificate issuance output: ${stdout}`);
          success = true;
        } catch (execError) {
          if (execError.stderr && execError.stderr.includes('MVCC_READ_CONFLICT')) {
            console.log(`Attempt ${retryCount + 1}/${MAX_RETRIES} failed with MVCC_READ_CONFLICT. Retrying...`);
            retryCount++;
            // Add a small delay before retrying to allow other transactions to complete
            await new Promise(resolve => setTimeout(resolve, 1000 * retryCount));
            continue;
          }

          console.error(`Peer command error during certificate issuance: ${execError.message}`);
          if (execError.stderr) {
            console.error(`stderr: ${execError.stderr}`);
          }

          lastError = execError;
          break;
        }
      } catch (error) {
        console.error('Error during CLI execution:', error);
        lastError = error;
        break;
      }
    }

    // Check if we succeeded after retries
    if (success) {
      return res.status(201).json({ message: `Certificate ${id} has been issued` });
    }

    // All retries failed, try SDK approach as a last resort
    if (lastError) {
      console.error('All CLI command attempts failed, falling back to SDK approach');

      try {
        const { contract, gateway } = await connectToNetwork('admin');

        // Submit transaction to create certificate
        console.log(`Issuing certificate ${id} using SDK`);

        // Include the certHash parameter
        await contract.submitTransaction('IssueCertificate', recipient, id, certHash, issuer);

        // Disconnect from the gateway
        await gateway.disconnect();

        res.status(201).json({ message: `Certificate ${id} has been issued` });
      } catch (sdkError) {
        console.error(`SDK approach also failed: ${sdkError.message}`);

        // Check if certificate already exists
        if (sdkError.message && sdkError.message.includes('already exists')) {
          return res.status(409).json({ error: `Certificate ${id} already exists` });
        }

        res.status(500).json({ error: sdkError.message });
      }
    } else {
      res.status(500).json({ error: 'Failed to issue certificate after multiple attempts' });
    }
  } catch (error) {
    console.error(`Failed to issue certificate: ${error}`);

    // Check if certificate already exists
    if (error.message && error.message.includes('already exists')) {
      return res.status(409).json({ error: `Certificate ${req.body.id} already exists` });
    }

    res.status(500).json({ error: error.message });
  }
});

// Revoke a certificate
router.delete('/:id', async (req, res) => {
  try {
    const certId = req.params.id;

    // Set up retry parameters
    const MAX_RETRIES = 5;
    let retryCount = 0;
    let success = false;
    let lastError = null;

    // Retry loop to handle MVCC_READ_CONFLICT errors
    while (retryCount < MAX_RETRIES && !success) {
      try {
        // Build the peer command as a single line to avoid shell interpretation issues
        let command = `cd ${process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')} && `;
        command += `export FABRIC_CFG_PATH=${path.resolve((process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')), '../config/')} && `;
        command += `export CORE_PEER_TLS_ENABLED=true && `;
        command += `export CORE_PEER_LOCALMSPID="Org1MSP" && `;
        command += `export CORE_PEER_TLS_ROOTCERT_FILE=${process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt && `;
        command += `export CORE_PEER_MSPCONFIGPATH=${process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp && `;
        command += `export CORE_PEER_ADDRESS=localhost:7051 && `;

        // Construct the chaincode command with properly escaped JSON
        command += `peer chaincode invoke `;
        command += `-o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls `;
        command += `--cafile ${process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem `;
        command += `-C ${channelName} -n ${chaincodeName} `;
        command += `--peerAddresses localhost:7051 --tlsRootCertFiles ${process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt `;
        command += `--peerAddresses localhost:9051 --tlsRootCertFiles ${process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network')}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt `;
        command += `-c '{"function":"RevokeCertificate","Args":["${certId}"]}' --waitForEvent`;

        console.log(`Executing command to revoke certificate: ${command}`);

        // Use promisify to convert the exec callback to a promise
        const util = require('util');
        const execPromise = util.promisify(exec);

        try {
          const { stdout, stderr } = await execPromise(command);

          if (stderr && stderr.includes('MVCC_READ_CONFLICT')) {
            console.log(`Attempt ${retryCount + 1}/${MAX_RETRIES} failed with MVCC_READ_CONFLICT. Retrying...`);
            retryCount++;
            // Add a small delay before retrying to allow other transactions to complete
            await new Promise(resolve => setTimeout(resolve, 1000 * retryCount));
            continue;
          } else if (stderr && !stderr.includes('Chaincode invoke successful')) {
            console.error(`Peer command stderr: ${stderr}`);
            lastError = new Error(stderr);
            break;
          }

          console.log(`Certificate revocation output: ${stdout}`);
          success = true;
        } catch (execError) {
          if (execError.stderr && execError.stderr.includes('MVCC_READ_CONFLICT')) {
            console.log(`Attempt ${retryCount + 1}/${MAX_RETRIES} failed with MVCC_READ_CONFLICT. Retrying...`);
            retryCount++;
            // Add a small delay before retrying to allow other transactions to complete
            await new Promise(resolve => setTimeout(resolve, 1000 * retryCount));
            continue;
          } else if (execError.stderr && execError.stderr.includes('does not exist')) {
            return res.status(404).json({ error: `Certificate ${certId} not found` });
          }

          console.error(`Peer command error during certificate revocation: ${execError.message}`);
          if (execError.stderr) {
            console.error(`stderr: ${execError.stderr}`);
          }

          lastError = execError;
          break;
        }
      } catch (error) {
        console.error('Error during CLI execution:', error);
        lastError = error;
        break;
      }
    }

    // Check if we succeeded after retries
    if (success) {
      return res.json({ message: `Certificate ${certId} has been revoked` });
    }

    // All retries failed, try SDK approach as a last resort
    if (lastError) {
      console.error('All CLI command attempts failed, falling back to SDK approach');

      try {
        const { contract, gateway } = await connectToNetwork('admin');

        // Submit transaction to revoke certificate
        console.log(`Revoking certificate ${certId} using SDK`);
        await contract.submitTransaction('RevokeCertificate', certId);

        // Disconnect from the gateway
        await gateway.disconnect();

        res.json({ message: `Certificate ${certId} has been revoked` });
      } catch (sdkError) {
        console.error(`SDK approach also failed: ${sdkError.message}`);

        // Check if certificate not found
        if (sdkError.message && (sdkError.message.includes('does not exist') || sdkError.message.includes('not found'))) {
          return res.status(404).json({ error: `Certificate ${certId} not found` });
        }

        res.status(500).json({ error: sdkError.message });
      }
    } else {
      res.status(500).json({ error: 'Failed to revoke certificate after multiple attempts' });
    }
  } catch (error) {
    console.error(`Failed to revoke certificate: ${error}`);

    // Check if certificate not found
    if (error.message && (error.message.includes('does not exist') || error.message.includes('not found'))) {
      return res.status(404).json({ error: `Certificate ${req.params.id} not found` });
    }

    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
