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

const orgNum = process.argv[2] || '1'; // Default to Org1 if not specified
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

        // Check to see if we've already enrolled the admin user
        const identity = await wallet.get('admin');
        if (identity) {
            console.log(`An identity for the admin user "admin" already exists in the wallet for Org${orgNum}`);
            return;
        }

        // Enroll the admin user, and import the new identity into the wallet
        const enrollment = await ca.enroll({ enrollmentID: 'admin', enrollmentSecret: 'adminpw' });
        const x509Identity = {
            credentials: {
                certificate: enrollment.certificate,
                privateKey: enrollment.key.toBytes(),
            },
            mspId: mspId,
            type: 'X.509',
        };
        await wallet.put('admin', x509Identity);
        console.log(`Successfully enrolled admin user "admin" and imported it into the wallet for Org${orgNum}`);
    } catch (error) {
        console.error(`Failed to enroll admin user "admin": ${error}`);
        process.exit(1);
    }
}

main();