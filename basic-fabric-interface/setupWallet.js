const { Wallets } = require('fabric-network');
const fs = require('fs');
const path = require('path');

async function main() {
  try {
    // Load environment variables
    require('dotenv').config();
    
    const testNetworkPath = process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../test-network');
    const orgName = process.env.ORG_NAME || 'org1';
    const orgDomain = process.env.ORG_DOMAIN || 'example.com';

    console.log(`Using test network path: ${testNetworkPath}`);

    // Path to user's MSP directory
    const cryptoPath = path.resolve(
      testNetworkPath,
      'organizations',
      'peerOrganizations',
      `${orgName}.${orgDomain}`,
      'users',
      `Admin@${orgName}.${orgDomain}`,
      'msp'
    );

    const certPath = path.resolve(
      cryptoPath,
      'signcerts',
      `Admin@${orgName}.${orgDomain}-cert.pem`
    );

    // Check for cert file
    if (!fs.existsSync(certPath)) {
      // Try alternative path structure common in test-network
      const altCertDir = path.resolve(cryptoPath, 'signcerts');
      
      if (fs.existsSync(altCertDir)) {
        const certFiles = fs.readdirSync(altCertDir);
        if (certFiles.length > 0) {
          const certPath = path.resolve(altCertDir, certFiles[0]);
          console.log(`Found certificate at alternative path: ${certPath}`);
        }
      }
    }

    // Try to locate the key file
    const keyDir = path.resolve(cryptoPath, 'keystore');
    let keyPath = null;
    
    if (fs.existsSync(keyDir)) {
      const keyFiles = fs.readdirSync(keyDir);
      if (keyFiles.length > 0) {
        keyPath = path.resolve(keyDir, keyFiles[0]);
        console.log(`Found private key at: ${keyPath}`);
      }
    }

    if (!fs.existsSync(certPath) || !keyPath) {
      throw new Error('Certificate or key not found');
    }

    const cert = fs.readFileSync(certPath).toString();
    const key = fs.readFileSync(keyPath).toString();

    // Create a new wallet
    const walletPath = path.join(__dirname, 'wallet');
    const wallet = await Wallets.newFileSystemWallet(walletPath);

    // Check if admin identity already exists
    const adminExists = await wallet.get('admin');
    if (adminExists) {
      console.log('An admin identity already exists in the wallet');
      console.log('Removing existing admin identity to refresh credentials');
      await wallet.remove('admin');
    }

    // Define the admin identity
    const orgMSPid = `${orgName.charAt(0).toUpperCase()}${orgName.slice(1)}MSP`;
    console.log(`Using MSP ID: ${orgMSPid}`);
    
    const identity = {
      credentials: {
        certificate: cert,
        privateKey: key,
      },
      mspId: orgMSPid,
      type: 'X.509',
    };

    // Import the identity into the wallet
    await wallet.put('admin', identity);
    console.log('Admin identity successfully imported to the wallet');

  } catch (error) {
    console.error(`Error setting up wallet: ${error}`);
    console.error(error.stack);
    process.exit(1);
  }
}

main().then(() => {
  console.log('Wallet setup completed');
}).catch((error) => {
  console.error(`Failed to set up wallet: ${error}`);
  process.exit(1);
});
