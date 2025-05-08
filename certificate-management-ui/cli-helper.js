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
    console.log(`Executing CLI query: ${funcName} with args: ${JSON.stringify(args)}`);

    // Set up environment variables for Fabric
    process.env.PATH = process.env.PATH + ':/home/deepak/Desktop/Hyperledger_fabric_certificate-main/bin';
    process.env.FABRIC_CFG_PATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/config';
    process.env.CORE_PEER_TLS_ENABLED = 'true';
    process.env.CORE_PEER_LOCALMSPID = 'Org1MSP';
    process.env.CORE_PEER_TLS_ROOTCERT_FILE = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt';
    process.env.CORE_PEER_MSPCONFIGPATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp';
    process.env.CORE_PEER_ADDRESS = 'localhost:7051';

    // Build args string
    const argsString = args.map(arg => `"${arg}"`).join(',');
    const ORDERER_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem';

    // Build the peer command with proper command structure
    // Fix: Handle empty args array correctly (no trailing comma)
    let command;
    if (args.length === 0) {
      command = `peer chaincode query -C certchannel -n cert_cc -c '{"Args":["${funcName}"]}' --tls --cafile ${ORDERER_CA}`;
    } else {
      command = `peer chaincode query -C certchannel -n cert_cc -c '{"Args":["${funcName}",${argsString}]}' --tls --cafile ${ORDERER_CA}`;
    }

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
