const { Wallets } = require('fabric-network');
const fs = require('fs');
const path = require('path');

async function main() {
    try {
        // Setup wallet directories
        const universityWalletPath = path.join(__dirname, 'wallet', 'org1');
        const studentWalletPath = path.join(__dirname, 'wallet', 'org2');
        const verifierWalletPath = path.join(__dirname, 'wallet', 'org3');

        // Create wallet instances
        const universityWallet = await Wallets.newFileSystemWallet(universityWalletPath);
        const studentWallet = await Wallets.newFileSystemWallet(studentWalletPath);
        const verifierWallet = await Wallets.newFileSystemWallet(verifierWalletPath);

        // Path to the network config files
        const testNetworkRoot = path.resolve(__dirname, '..', 'test-network');

        // Setup for Org1 (University)
        await setupOrgUsingExistingCredentials(
            'org1.example.com',
            'Org1MSP',
            universityWallet,
            testNetworkRoot
        );

        // Setup for Org2 (Student)
        await setupOrgUsingExistingCredentials(
            'org2.example.com',
            'Org2MSP',
            studentWallet,
            testNetworkRoot
        );

        // Check if Org3 exists (it might not if the addOrg3 script hasn't been run)
        const org3Path = path.join(testNetworkRoot, 'organizations', 'peerOrganizations', 'org3.example.com');
        if (fs.existsSync(org3Path)) {
            // Setup for Org3 (Verifier)
            await setupOrgUsingExistingCredentials(
                'org3.example.com',
                'Org3MSP',
                verifierWallet,
                testNetworkRoot
            );
            console.log('Org3 (Verifier) wallet setup complete!');
        } else {
            console.log('Org3 (Verifier) not found. This is normal if you haven\'t run addOrg3.sh yet.');
        }

        console.log('Wallet setup complete!');
    } catch (error) {
        console.error(`Failed to set up wallet: ${error}`);
        process.exit(1);
    }
}

async function setupOrgUsingExistingCredentials(orgDomain, orgMSP, wallet, networkRoot) {
    console.log(`Setting up wallet for ${orgDomain} (${orgMSP})...`);

    try {
        // Check if admin identity already exists in wallet
        const adminExists = await wallet.get('admin');
        if (adminExists) {
            console.log(`An identity for admin already exists in the wallet for ${orgMSP}`);
            return;
        }

        // Path to organization's admin user MSP directory
        const adminMSPPath = path.join(
            networkRoot,
            'organizations',
            'peerOrganizations',
            orgDomain,
            'users',
            `Admin@${orgDomain}`
        );

        // Read the admin certificate
        const certPath = path.join(adminMSPPath, 'msp', 'signcerts', `Admin@${orgDomain}-cert.pem`);
        const cert = fs.readFileSync(certPath, 'utf8');

        // Find the private key file - it has a random filename
        const keyDirPath = path.join(adminMSPPath, 'msp', 'keystore');
        const keyFiles = fs.readdirSync(keyDirPath);
        if (keyFiles.length === 0) {
            throw new Error(`No private key files found in ${keyDirPath}`);
        }
        const keyPath = path.join(keyDirPath, keyFiles[0]);
        const key = fs.readFileSync(keyPath, 'utf8');

        // Create the admin identity
        const identity = {
            credentials: {
                certificate: cert,
                privateKey: key,
            },
            mspId: orgMSP,
            type: 'X.509',
        };

        // Import the admin identity into the wallet
        await wallet.put('admin', identity);
        console.log(`${orgMSP} admin credentials added to wallet`);
    } catch (error) {
        console.error(`Error setting up ${orgMSP} wallet:`, error);
        throw error;
    }
}

main();
