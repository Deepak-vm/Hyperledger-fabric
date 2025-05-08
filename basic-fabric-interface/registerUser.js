/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const { Wallets } = require('fabric-network');
const FabricCAServices = require('fabric-ca-client');
const path = require('path');
const fs = require('fs');

// Default values if not provided via command line
const orgNum = process.argv[2] || '1';
const userId = process.argv[3] || 'appUser';
const mspId = `Org${orgNum}MSP`;

async function main() {
    try {
        // Load the connection profile
        const ccpPath = path.resolve(__dirname, '..', 'test-network', 'organizations', 'peerOrganizations',
            `org${orgNum}.example.com`, `connection-org${orgNum}.json`);
        const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));

        // Create a CA client for interacting with the CA
        const caInfo = ccp.certificateAuthorities[`ca.org${orgNum}.example.com`];
        const caTLSCACerts = caInfo.tlsCACerts.pem;
        const ca = new FabricCAServices(caInfo.url, { trustedRoots: caTLSCACerts, verify: false }, caInfo.caName);

        // Create a file system wallet for managing identities
        const walletPath = path.join(__dirname, 'wallet');
        const wallet = await Wallets.newFileSystemWallet(walletPath);
        console.log(`Wallet path: ${walletPath}`);

        // Check if user already exists in the wallet
        const userIdentity = await wallet.get(userId);
        if (userIdentity) {
            console.log(`An identity for the user "${userId}" already exists in the wallet for Org${orgNum}`);
            return;
        }

        // Check if admin exists in the wallet
        const adminIdentity = await wallet.get('admin');
        if (!adminIdentity) {
            console.log(`An identity for the admin user "admin" does not exist in the wallet for Org${orgNum}`);
            console.log('Run the enrollAdmin.js application before retrying');
            return;
        }

        // Build a user object for authenticating with the CA
        const provider = wallet.getProviderRegistry().getProvider(adminIdentity.type);
        const adminUser = await provider.getUserContext(adminIdentity, 'admin');

        // Register the user, enroll the user, and import the new identity into the wallet
        const secret = await ca.register({
            affiliation: `org${orgNum}.department1`,
            enrollmentID: userId,
            role: 'client'
        }, adminUser);

        const enrollment = await ca.enroll({
            enrollmentID: userId,
            enrollmentSecret: secret
        });

        const x509Identity = {
            credentials: {
                certificate: enrollment.certificate,
                privateKey: enrollment.key.toBytes(),
            },
            mspId: mspId,
            type: 'X.509',
        };

        await wallet.put(userId, x509Identity);
        console.log(`Successfully registered and enrolled user "${userId}" and imported it into the wallet for Org${orgNum}`);

    } catch (error) {
        console.error(`Failed to register user "${userId}": ${error}`);
        process.exit(1);
    }
}

main();