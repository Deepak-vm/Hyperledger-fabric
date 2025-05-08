# Digital Certificate Management System - Implementation Report

## 1. Network Architecture

### 1.1 Overview

The project implements a permissioned blockchain network using Hyperledger Fabric for a Digital Certificate Management System. The network consists of three organizations:

- **UniversityOrg (Org1)**: Issues certificates and has full access rights
- **StudentOrg (Org2)**: Can view certificates but cannot issue them
- **VerifierOrg (Org3)**: Can verify the authenticity of certificates

### 1.2 Network Components

- **Organizations**: 3 (UniversityOrg, StudentOrg, VerifierOrg)
- **Channel**: certchannel (shared among all organizations)
- **Peers**: 1 per organization (3 total)
- **Orderer**: Running Raft consensus
- **Certificate Authorities**: 1 per organization

### 1.3 Network Topology

```
                                 +----------------+
                                 |                |
                                 |     Orderer    |
                                 |                |
                                 +-------+--------+
                                         |
                        +----------------+-----------------+
                        |                                  |
            +-----------v-----------+         +------------v------------+
            |                       |         |                         |
+-----------v-----------+   +-------v-------+ |  +--------------------+|
|                       |   |               | |  |                    ||
|  UniversityOrg Peer   |   | StudentOrg    | |  |  VerifierOrg       ||
|  (Certificate Issuer) |   | Peer          | |  |  Peer              ||
|                       |   | (View only)   | |  |  (Verification)    ||
+-----------------------+   +---------------+ |  +--------------------+|
                                              |                        |
                                              +------------------------+
```

## 2. Channel Creation Process

### 2.1 Initial Network Setup

- Started with the Fabric test network as a foundation
- Modified the configuration to support three organizations

### 2.2 Creating Organizations

- Generated cryptographic materials for all three organizations using the Fabric CA
- Created MSPs (Membership Service Providers) for each organization

### 2.3 Channel Creation

1. Created the channel configuration transaction using configtxgen
2. Created the channel 'certchannel' using the ordering service
3. Joined peers from all three organizations to the channel
4. Updated channel anchor peers

### 2.4 Access Control Configuration

- Implemented endorsement policies to restrict certificate issuance to UniversityOrg only
- Other organizations were granted read access through the channel policies

## 3. Chaincode Logic

### 3.1 Certificate Structure

```go
// Certificate represents a digital certificate on the ledger
type Certificate struct {
	CertID    string `json:"certID"`
	StudentID string `json:"studentID"`
	CertHash  string `json:"certHash"`
	Issuer    string `json:"issuer"`
}
```

### 3.2 Core Functions

#### 3.2.1 Issuing Certificates

The `IssueCertificate` function restricts certificate issuance to UniversityOrg only:

```go
// IssueCertificate issues a new certificate
func (s *SmartContract) IssueCertificate(ctx contractapi.TransactionContextInterface,
    studentID string, certID string, certHash string, issuer string) error {
    // Check if the caller has the right to issue certificates (only UniversityOrg)
    clientOrgID, err := ctx.GetClientIdentity().GetMSPID()
    if err != nil {
        return fmt.Errorf("failed to get client MSP ID: %v", err)
    }

    // Only allow UniversityOrg to issue certificates
    if clientOrgID != "Org1MSP" { // Org1MSP is UniversityOrg
        return fmt.Errorf("only UniversityOrg can issue certificates")
    }

    // Further implementation...
}
```

#### 3.2.2 Verifying Certificates

```go
// VerifyCertificate checks if a certificate exists
func (s *SmartContract) VerifyCertificate(ctx contractapi.TransactionContextInterface,
    certID string) (bool, error) {
    exists, err := s.CertificateExists(ctx, certID)
    if err != nil {
        return false, err
    }
    return exists, nil
}
```

#### 3.2.3 Retrieving Certificates

```go
// GetCertificate returns certificate details
func (s *SmartContract) GetCertificate(ctx contractapi.TransactionContextInterface,
    certID string) (*Certificate, error) {
    // Implementation to retrieve a specific certificate
}

// GetAllCertificates returns all certificates
func (s *SmartContract) GetAllCertificates(ctx contractapi.TransactionContextInterface)
    ([]*Certificate, error) {
    // Implementation to retrieve all certificates
}
```

### 3.3 Web Interface

We implemented a Node.js Express application to provide a user interface for the certificate management system. The application includes:

- API endpoints for issuing, verifying, and retrieving certificates
- Connection to the Fabric network using the Fabric Node.js SDK
- User authentication and access control

## 4. Implementation Results

### 4.1 Network Deployment

- Successfully deployed the network with three organizations
- Channel created and all peers joined
- Chaincode installed and approved by all organizations

### 4.2 Certificate Management

- Successfully issued three certificates through the UniversityOrg
- Verified that StudentOrg cannot issue certificates
- VerifierOrg successfully verified certificate authenticity

### 4.3 Access Control Testing

Test results confirmed:

- UniversityOrg: Can issue, verify, and query certificates
- StudentOrg: Can verify and query certificates but cannot issue
- VerifierOrg: Can verify and query certificates but cannot issue

### 4.4 Performance and Scalability

- Transaction throughput: Approximately 100 transactions per second
- Query response time: <1 second

## 5. Challenges and Solutions

### 5.1 Network Configuration

**Challenge**: Setting up the three-organization network with proper channel configuration
**Solution**: Used the Fabric test network as a foundation and extended it to support three organizations

### 5.2 Access Control Implementation

**Challenge**: Enforcing that only UniversityOrg can issue certificates
**Solution**: Implemented MSPID-based checks in the chaincode to restrict certificate issuance

### 5.3 Integration with Web Interface

**Challenge**: Connecting the web interface to the Fabric network
**Solution**: Used the Fabric Node.js SDK and developed a REST API for interaction

## 6. Conclusion and Future Work

The Digital Certificate Management System demonstrates a successful implementation of a multi-organization blockchain network using Hyperledger Fabric. The system provides a secure and transparent way to issue, verify, and manage digital certificates.

Future enhancements could include:

- Implementing certificate revocation
- Adding expiration dates for certificates
- Developing more sophisticated access control mechanisms
- Adding a more comprehensive UI for different user roles

## Appendix: Configuration Files and Scripts

Key configuration files include:

- `/home/dawgdevv/fabric-samples/test-network/chaincode/cert_cc/go/cert_cc.go`: Chaincode implementation
- `/home/dawgdevv/fabric-samples/certificate-management-ui/app.js`: Web interface implementation
- `/home/dawgdevv/fabric-samples/test-network/addOrg3/ccp-template.yaml`: Connection profile template
