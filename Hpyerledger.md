# Assignment: Implementing a Multi- Organization Blockchain Network with Hyperledger Fabric

## Objective

To understand the architecture, components, and working of Hyperledger Fabric by setting
up a permissioned blockchain network with multiple organizations and channels, and
deploying chaincode (smart contract) for a sample use case.

## Background

Hyperledger Fabric is a permissioned blockchain framework designed for enterprise
applications. It allows for modular architecture, pluggable consensus, and secure channels
between organizations. This assignment will give hands-on experience in network setup,
channel management, and chaincode deployment.

## Use Case: Digital Certificate Management System

You are tasked with building a basic blockchain network where:

- UniversityOrg issues certificates.
- StudentOrg can view their own certificates.
- VerifierOrg can verify the authenticity of certificates.

Each organization has its own peer node, and communication occurs over a shared channel.
A smart contract will manage certificate issuance and verification.

## Tasks

### 1. Network Setup

- Use Hyperledger Fabric Test Network (or build your own from scratch).
- Set up 3 organizations: UniversityOrg, StudentOrg, and VerifierOrg.
- Create a channel certchannel and join all peers to it.

### 2. Chaincode Development

- Write a simple chaincode (cert_cc) in Go/Node.js that allows:
- issueCertificate(studentID, certID, certHash, issuer)
- verifyCertificate(certID)
- getCertificate(certID)

### 3. Chaincode Deployment

- Deploy the chaincode to all peers in the network.
- Invoke chaincode using CLI or SDK to:
- Issue at least 3 certificates.
- Verify and query them.

### 4. Privacy and Access

- Ensure that StudentOrg cannot issue certificates.
- Only UniversityOrg has write access, others only read.

### 5. Documentation

- Include configuration files, scripts, and instructions.
- Write a report (3–4 pages) covering:
- Network architecture
- Channel creation process
- Chaincode logic
- Screenshots of peer joins, transactions, and query results

## Deliverables

- Project folder with:
- crypto-config, configtx.yaml, and docker-compose files
- Chaincode files
- Scripts for starting the network and invoking chaincode
- PDF report with documentation and screenshots

## Evaluation Criteria

Component Marks

Network Setup 20

Chaincode Implementation 20

Channel and Access Management 15

Correct Execution of Functions 15

Code Structure and Best Practices 10

Report Quality and Screenshots 20

Total 100
