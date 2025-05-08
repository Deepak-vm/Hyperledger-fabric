/**
 * Test script to issue a certificate using the CLI approach
 * Run with: node test-issue.js
 */

const { exec } = require('child_process');
const util = require('util');
const execAsync = util.promisify(exec);

async function testIssueCertificate() {
    try {
        console.log('Testing certificate issuance with CLI approach...');

        // Set up environment variables for Fabric
        process.env.PATH = process.env.PATH + ':/home/deepak/Desktop/Hyperledger_fabric_certificate-main/bin';
        process.env.FABRIC_CFG_PATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/config';
        process.env.CORE_PEER_TLS_ENABLED = 'true';
        process.env.CORE_PEER_LOCALMSPID = 'Org1MSP';
        process.env.CORE_PEER_TLS_ROOTCERT_FILE = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt';
        process.env.CORE_PEER_MSPCONFIGPATH = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp';
        process.env.CORE_PEER_ADDRESS = 'localhost:7051';

        // Certificate details for the test
        const studentID = 'test_student_' + Date.now();
        const certID = 'test_cert_' + Date.now();
        const certHash = 'test_hash_' + Date.now();
        const issuer = 'UniversityOrg';

        // Define the paths to TLS certificates
        const ORDERER_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem';
        const ORG1_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt';
        const ORG2_CA = '/home/deepak/Desktop/Hyperledger_fabric_certificate-main/test-network/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt';

        // Build the command for issuing a certificate
        const command = `peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
      --tls --cafile ${ORDERER_CA} -C certchannel -n cert_cc \
      --peerAddresses localhost:7051 --tlsRootCertFiles ${ORG1_CA} \
      --peerAddresses localhost:9051 --tlsRootCertFiles ${ORG2_CA} \
      -c '{"function":"IssueCertificate","Args":["${studentID}","${certID}","${certHash}","${issuer}"]}'`;

        console.log('\nExecuting command:', command);

        // Execute the command
        const { stdout, stderr } = await execAsync(command);

        if (stderr && !stderr.includes('status:200')) {
            console.error('\nCommand error:', stderr);
            console.error('Certificate issuance failed');
        } else {
            console.log('\nCommand output:', stdout || 'Command executed successfully');

            // Wait for transaction to be committed
            console.log('\nWaiting for transaction to be committed...');
            await new Promise(resolve => setTimeout(resolve, 3000));

            // Verify the certificate was issued by querying it
            console.log('\nVerifying certificate was created...');
            const verifyCommand = `peer chaincode query -C certchannel -n cert_cc -c '{"Args":["GetCertificate", "${certID}"]}' --tls --cafile ${ORDERER_CA}`;

            const verifyResult = await execAsync(verifyCommand);
            console.log('\nCertificate verification result:', verifyResult.stdout);

            console.log('\n✅ Test completed successfully!');
        }
    } catch (error) {
        console.error('\n❌ Error executing test:', error.message);
    }
}

testIssueCertificate();