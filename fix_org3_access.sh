#!/bin/bash
set -e

# Navigate to the test network directory
cd ~/Desktop/Hyperledger_fabric_certificate-main/test-network

# Set environment variables
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config

# Ensure Org3 user is properly registered with the CA
echo "Registering and enrolling Org3 users..."

# Set environment variables for Org3
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

# Create a connection profile for Org3
echo "Creating connection profile for Org3..."
mkdir -p organizations/peerOrganizations/org3.example.com/connection-org3

cat > organizations/peerOrganizations/org3.example.com/connection-org3/connection-org3.json << CONN
{
    "name": "test-network-org3",
    "version": "1.0.0",
    "client": {
        "organization": "Org3",
        "connection": {
            "timeout": {
                "peer": {
                    "endorser": "300"
                }
            }
        }
    },
    "organizations": {
        "Org3": {
            "mspid": "Org3MSP",
            "peers": [
                "peer0.org3.example.com"
            ],
            "certificateAuthorities": [
                "ca.org3.example.com"
            ]
        }
    },
    "peers": {
        "peer0.org3.example.com": {
            "url": "grpcs://localhost:11051",
            "tlsCACerts": {
                "pem": "$(cat organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt | sed -e 's/\$/\\n/' | tr -d '\n')"
            },
            "grpcOptions": {
                "ssl-target-name-override": "peer0.org3.example.com",
                "hostnameOverride": "peer0.org3.example.com"
            }
        }
    },
    "certificateAuthorities": {
        "ca.org3.example.com": {
            "url": "https://localhost:11054",
            "caName": "ca-org3",
            "tlsCACerts": {
                "pem": ["$(cat organizations/peerOrganizations/org3.example.com/ca/ca.org3.example.com-cert.pem | sed -e 's/\$/\\n/' | tr -d '\n')"]
            },
            "httpOptions": {
                "verify": false
            }
        }
    }
}
CONN

# Copy the connection profile to the certificate-management-ui folder
cp organizations/peerOrganizations/org3.example.com/connection-org3/connection-org3.json ../certificate-management-ui/connection-org3.json

echo "Setting up the wallet for Org3..."
cd ../certificate-management-ui

# Update setupWallet.js script to include Org3
cat > setupWallet.js << 'SETUPWALLET'
const { Wallets } = require('fabric-network');
const FabricCAServices = require('fabric-ca-client');
const fs = require('fs');
const path = require('path');

async function main() {
    try {
        // Set up the wallet for all organizations
        const wallet = await Wallets.newFileSystemWallet('./wallet');
        
        // Path to the network config files
        const testNetworkRoot = path.resolve(__dirname, '..', 'test-network');
        
        // Setup for Org1 (University)
        await setupOrg(
            'org1.example.com',
            'university',
            'Org1MSP',
            wallet,
            testNetworkRoot
        );
        
        // Setup for Org2 (Student)
        await setupOrg(
            'org2.example.com',
            'student',
            'Org2MSP',
            wallet,
            testNetworkRoot
        );
        
        // Setup for Org3 (Verifier)
        await setupOrg(
            'org3.example.com',
            'verifier',
            'Org3MSP',
            wallet,
            testNetworkRoot
        );
        
        console.log('Wallet setup complete!');
    } catch (error) {
        console.error(`Failed to set up wallet: ${error}`);
        process.exit(1);
    }
}

async function setupOrg(orgDomain, orgName, orgMSP, wallet, networkRoot) {
    console.log(`Setting up wallet for ${orgName} organization (${orgMSP})...`);
    
    // Path to organization's CA cert
    const caCertPath = path.join(
        networkRoot,
        'organizations',
        'peerOrganizations',
        orgDomain,
        'ca',
        `ca.${orgDomain}-cert.pem`
    );
    
    // Read the CA certificate
    const caCert = fs.readFileSync(caCertPath, 'utf8');
    
    // Create a new CA client for the organization
    let caURL;
    if (orgName === 'university') {
        caURL = 'https://localhost:7054';
    } else if (orgName === 'student') {
        caURL = 'https://localhost:8054';
    } else if (orgName === 'verifier') {
        caURL = 'https://localhost:11054';
    }
    
    const ca = new FabricCAServices(caURL, { trustedRoots: caCert, verify: false }, `ca-${orgName}`);
    
    // Enroll the admin user
    const enrollment = await ca.enroll({
        enrollmentID: 'admin',
        enrollmentSecret: 'adminpw'
    });
    
    // Create the admin identity
    const identity = {
        credentials: {
            certificate: enrollment.certificate,
            privateKey: enrollment.key.toBytes(),
        },
        mspId: orgMSP,
        type: 'X.509',
    };
    
    // Import the admin identity into the wallet
    await wallet.put(`${orgName}admin`, identity);
    console.log(`${orgName} admin credentials added to wallet`);
}

main();
SETUPWALLET

# Run the updated wallet setup
echo "Running wallet setup..."
node setupWallet.js

# Update app.js to fix Org3 access
cat > app.js << 'APPJS'
const express = require('express');
const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(express.static('public'));
app.use(express.json());

// Get connection profiles for each organization
const getConnectionProfile = (org) => {
    let profile;
    if (org === 'university') {
        profile = path.resolve(__dirname, '..', 'test-network', 'organizations', 'peerOrganizations', 'org1.example.com', 'connection-org1.json');
    } else if (org === 'student') {
        profile = path.resolve(__dirname, '..', 'test-network', 'organizations', 'peerOrganizations', 'org2.example.com', 'connection-org2.json');
    } else if (org === 'verifier') {
        profile = path.resolve(__dirname, 'connection-org3.json');
    }
    return JSON.parse(fs.readFileSync(profile, 'utf8'));
};

// Create organization-specific endpoints
const createOrgEndpoint = (orgName, orgMSP) => {
    app.get(`/api/${orgName}/certificates`, async (req, res) => {
        try {
            // Get the wallet and connection profile
            const wallet = await Wallets.newFileSystemWallet('./wallet');
            const gateway = new Gateway();
            const connectionProfile = getConnectionProfile(orgName);
            
            // Connect to the gateway
            await gateway.connect(connectionProfile, {
                wallet,
                identity: `${orgName}admin`,
                discovery: { enabled: true, asLocalhost: true }
            });
            
            // Get the channel and contract
            const network = await gateway.getNetwork('certchannel');
            const contract = network.getContract('cert_cc');
            
            // Query the chaincode
            const result = await contract.evaluateTransaction('getAllCertificates');
            
            // Disconnect from the gateway
            await gateway.disconnect();
            
            // Send the response
            res.json({ success: true, certificates: JSON.parse(result.toString()) });
        } catch (error) {
            console.error(`Error getting certificates as ${orgName}: ${error}`);
            res.status(500).json({ success: false, error: error.message });
        }
    });
};

// Create endpoints for each organization
createOrgEndpoint('university', 'Org1MSP');
createOrgEndpoint('student', 'Org2MSP');
createOrgEndpoint('verifier', 'Org3MSP');

// Start the server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log('Organization-specific API endpoints are available at /api/{university|student|verifier}/certificates');
});
APPJS

echo "Fix script completed!"
