const { exec } = require('child_process');
const util = require('util');
const execAsync = util.promisify(exec);

/**
 * Helper function to issue a certificate using the peer CLI
 * This ensures proper command formatting for chaincode invocation
 */
async function issueCertificate(studentID, certID, certHash, issuer) {
    try {
        console.log(`Issuing certificate: ${certID} for student: ${studentID}`);

        // Set up environment variables for Fabric
        process.env.PATH = process.env.PATH + ':/home/deepak/Desktop/Hyperledger_fabric_certificate-main/bin';
        process.env.FABRIC_CFG_PATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/config';
        process.env.CORE_PEER_TLS_ENABLED = 'true';
        process.env.CORE_PEER_LOCALMSPID = 'Org1MSP';
        process.env.CORE_PEER_TLS_ROOTCERT_FILE = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt';
        process.env.CORE_PEER_MSPCONFIGPATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp';
        process.env.CORE_PEER_ADDRESS = 'localhost:7051';

        // Define the paths to TLS certificates
        const ORDERER_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem';
        const ORG1_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt';
        const ORG2_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt';

        // Build the peer command with proper command structure
        const command = `peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
      --tls --cafile ${ORDERER_CA} -C certchannel -n cert_cc \
      --peerAddresses localhost:7051 --tlsRootCertFiles ${ORG1_CA} \
      --peerAddresses localhost:9051 --tlsRootCertFiles ${ORG2_CA} \
      -c '{"function":"IssueCertificate","Args":["${studentID}","${certID}","${certHash}","${issuer}"]}'`;

        console.log('Executing command:', command);

        // Execute the command
        const { stdout, stderr } = await execAsync(command);

        if (stderr && !stderr.includes('status:200')) {
            console.error('CLI command error:', stderr);
        }

        // Wait for transaction to be processed
        await new Promise(resolve => setTimeout(resolve, 3000));

        console.log('Certificate issued successfully!');
        return { success: true, message: 'Certificate issued successfully' };
    } catch (error) {
        console.error('Error issuing certificate:', error.message);
        return { success: false, error: error.message };
    }
}

// Direct execution
if (require.main === module) {
    const args = process.argv.slice(2);

    if (args.length < 3) {
        console.log('Usage: node issue-certificate.js <studentID> <certID> <certHash> [issuer]');
        console.log('Example: node issue-certificate.js student123 cert456 abc123 UniversityOrg');
        process.exit(1);
    }

    const studentID = args[0];
    const certID = args[1];
    const certHash = args[2];
    const issuer = args[3] || 'UniversityOrg';

    issueCertificate(studentID, certID, certHash, issuer)
        .then(result => {
            console.log(result);
            process.exit(0);
        })
        .catch(error => {
            console.error('Failed to issue certificate:', error);
            process.exit(1);
        });
} else {
    // Export for use as a module
    module.exports = { issueCertificate };
}