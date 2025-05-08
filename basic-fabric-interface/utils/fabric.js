const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs');

// Path to the network configuration
const testNetworkRoot = process.env.TEST_NETWORK_PATH || path.resolve(__dirname, '../../test-network');
const orgName = process.env.ORG_NAME || 'org1';
const orgDomain = process.env.ORG_DOMAIN || 'example.com';
const channelName = process.env.CHANNEL_NAME || 'certchannel';
const chaincodeName = process.env.CHAINCODE_NAME || 'cert_cc';

const ccpPath = path.resolve(
    testNetworkRoot,
    'organizations',
    'peerOrganizations',
    `${orgName}.${orgDomain}`,
    `connection-${orgName}.json`
);

// Create a new gateway for connecting to the peer node
async function connectToNetwork(userId, enableDiscovery = false) {
    try {
        // Load the network configuration
        let ccp;
        try {
            const fileExists = fs.existsSync(ccpPath);
            if (!fileExists) {
                console.error(`Connection profile not found at ${ccpPath}`);
                // Try alternative path that might work with the test-network 
                const alternativePath = path.resolve(
                    testNetworkRoot,
                    'organizations/peerOrganizations/org1.example.com/connection-org1.json'
                );
                if (fs.existsSync(alternativePath)) {
                    ccp = JSON.parse(fs.readFileSync(alternativePath, 'utf8'));
                    console.log(`Loaded connection profile from alternative path: ${alternativePath}`);
                } else {
                    throw new Error(`Configuration file not found: ${ccpPath}`);
                }
            } else {
                ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));
                console.log(`Loaded connection profile from ${ccpPath}`);
            }
        } catch (error) {
            console.error(`Error loading connection profile: ${error}`);
            throw new Error(`Unable to load connection profile: ${error.message}`);
        }

        // Create a new wallet for identity management
        const walletPath = path.join(process.cwd(), 'wallet');
        const wallet = await Wallets.newFileSystemWallet(walletPath);

        // Check if the user identity exists in the wallet
        const identity = await wallet.get(userId);
        if (!identity) {
            console.error(`Identity not found in the wallet: ${userId}`);
            throw new Error(`Identity not found in the wallet: ${userId}`);
        }
        console.log(`Found identity for ${userId} in wallet`);

        // Create a new gateway instance for interacting with the fabric network
        const gateway = new Gateway();

        // Always connect with discovery disabled to avoid permission issues
        await gateway.connect(ccp, {
            wallet,
            identity: userId,
            discovery: { enabled: false, asLocalhost: true }
        });

        console.log(`Connected to gateway as ${userId}`);

        // Get the network
        let network;
        try {
            network = await gateway.getNetwork(channelName);
            console.log(`Connected to channel: ${channelName}`);
        } catch (error) {
            console.error(`Failed to connect to channel ${channelName}: ${error}`);
            throw error;
        }

        // Get the contract
        let contract;
        try {
            contract = network.getContract(chaincodeName);
            console.log(`Got contract: ${chaincodeName}`);
        } catch (error) {
            console.error(`Failed to get contract ${chaincodeName}: ${error}`);
            throw error;
        }

        return { gateway, network, contract };
    } catch (error) {
        console.error(`Failed to connect to the network: ${error}`);
        throw error;
    }
}

// Validate that the network configuration exists and is accessible
async function checkNetworkConfig() {
    try {
        // Check test network path
        if (!fs.existsSync(testNetworkRoot)) {
            console.warn(`Test network path ${testNetworkRoot} does not exist`);
            return { success: false, message: `Test network path not found: ${testNetworkRoot}` };
        }

        // Try to load the connection profile
        let connectionProfile;
        let profilePath;

        try {
            if (fs.existsSync(ccpPath)) {
                connectionProfile = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));
                profilePath = ccpPath;
            } else {
                // Try alternative path
                const alternativePath = path.resolve(
                    testNetworkRoot,
                    'organizations/peerOrganizations/org1.example.com/connection-org1.json'
                );
                if (fs.existsSync(alternativePath)) {
                    connectionProfile = JSON.parse(fs.readFileSync(alternativePath, 'utf8'));
                    profilePath = alternativePath;
                } else {
                    return {
                        success: false,
                        message: `Connection profile not found at ${ccpPath} or alternative paths`
                    };
                }
            }
            console.log(`Found connection profile at: ${profilePath}`);
        } catch (error) {
            return { success: false, message: `Error parsing connection profile: ${error.message}` };
        }

        // Check if wallet has admin identity
        const walletPath = path.join(process.cwd(), 'wallet');
        const wallet = await Wallets.newFileSystemWallet(walletPath);
        const identity = await wallet.get('admin');

        if (!identity) {
            return {
                success: false,
                message: 'Admin identity not found in wallet. Run setupWallet.js first.'
            };
        }

        console.log('Admin identity found in wallet');
        console.log('MSP ID:', identity.mspId);

        return {
            success: true,
            message: 'Network configuration is valid',
            details: {
                profilePath,
                mspId: identity.mspId,
                channelName,
                chaincodeName
            }
        };
    } catch (error) {
        return { success: false, message: `Error checking network config: ${error.message}` };
    }
}

module.exports = {
    connectToNetwork,
    checkNetworkConfig,
    channelName,
    chaincodeName
};
