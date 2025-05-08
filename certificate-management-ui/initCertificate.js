const { Gateway, Wallets } = require('fabric-network');
const fs = require('fs');
const path = require('path');

async function main() {
    try {
        // Load the network configuration
        const ccpPath = path.resolve(__dirname, '..', 'test-network', 'organizations', 'peerOrganizations',
            'org1.example.com', 'connection-org1.json');
        const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));

        // Create a new file system based wallet for managing identities
        const walletPath = path.join(__dirname, 'wallet', 'org1');
        const wallet = await Wallets.newFileSystemWallet(walletPath);
        console.log(`Wallet path: ${walletPath}`);

        // Check to see if we've already enrolled the admin user
        const identity = await wallet.get('admin');
        if (!identity) {
            console.log('Admin identity can not be found in the wallet');
            return;
        }

        // Create a new gateway for connecting to our peer node
        const gateway = new Gateway();
        await gateway.connect(ccp, {
            wallet,
            identity: 'admin',
            discovery: { enabled: false }
        });

        // Get the network (channel) our contract is deployed to
        const network = await gateway.getNetwork('certchannel');

        // Get the contract from the network
        const contract = network.getContract('cert_cc');

        // Issue a test certificate
        console.log('Submitting transaction to issue a test certificate...');

        // Create transaction and explicitly set endorsing peers from both organizations
        const tx = contract.createTransaction('IssueCertificate');

        // Get Org1 and Org2 endorsing peers
        const org1PeerEndpoint = 'localhost:7051';
        const org2PeerEndpoint = 'localhost:9051';

        // Set endorsing peers explicitly
        const org1TlsRootCert = fs.readFileSync(
            path.resolve(__dirname, '..', 'test-network', 'organizations', 'peerOrganizations',
                'org1.example.com', 'peers', 'peer0.org1.example.com', 'tls', 'ca.crt')
        );

        const org2TlsRootCert = fs.readFileSync(
            path.resolve(__dirname, '..', 'test-network', 'organizations', 'peerOrganizations',
                'org2.example.com', 'peers', 'peer0.org2.example.com', 'tls', 'ca.crt')
        );

        tx.setEndorsingPeers([org1PeerEndpoint, org2PeerEndpoint]);
        tx.setEndorsingOrganizations('Org1MSP', 'Org2MSP');

        // Submit the transaction
        await tx.submit(
            'student001',
            'cert001',
            'hash001',
            'UniversityOrg'
        );

        console.log('Transaction has been submitted');

        // Disconnect from the gateway
        await gateway.disconnect();

    } catch (error) {
        console.error(`Failed to initialize the certificate: ${error}`);
        process.exit(1);
    }
}

main();