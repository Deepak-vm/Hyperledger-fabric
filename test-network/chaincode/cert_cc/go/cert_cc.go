package main

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// Certificate represents a digital certificate on the ledger
type Certificate struct {
	CertID    string `json:"certID"`
	StudentID string `json:"studentID"`
	CertHash  string `json:"certHash"`
	Issuer    string `json:"issuer"`
}

// SmartContract provides functions for certificate management
type SmartContract struct {
	contractapi.Contract
}

// InitLedger adds sample data to the ledger
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	return nil
}

// IssueCertificate issues a new certificate
func (s *SmartContract) IssueCertificate(ctx contractapi.TransactionContextInterface, studentID string, certID string, certHash string, issuer string) error {
	// Check if the caller has the right to issue certificates (only UniversityOrg)
	clientOrgID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return fmt.Errorf("failed to get client MSP ID: %v", err)
	}

	// Only allow UniversityOrg to issue certificates
	if clientOrgID != "Org1MSP" { // Org1MSP is UniversityOrg
		return fmt.Errorf("only UniversityOrg can issue certificates")
	}

	exists, err := s.CertificateExists(ctx, certID)
	if err != nil {
		return err
	}
	if exists {
		return fmt.Errorf("the certificate %s already exists", certID)
	}

	certificate := Certificate{
		CertID:    certID,
		StudentID: studentID,
		CertHash:  certHash,
		Issuer:    issuer,
	}

	certJSON, err := json.Marshal(certificate)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(certID, certJSON)
}

// VerifyCertificate checks if a certificate exists and returns verification status
func (s *SmartContract) VerifyCertificate(ctx contractapi.TransactionContextInterface, certID string) (bool, error) {
	exists, err := s.CertificateExists(ctx, certID)
	if err != nil {
		return false, err
	}
	return exists, nil
}

// GetCertificate returns the certificate details stored in the ledger
func (s *SmartContract) GetCertificate(ctx contractapi.TransactionContextInterface, certID string) (*Certificate, error) {
	certJSON, err := ctx.GetStub().GetState(certID)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if certJSON == nil {
		return nil, fmt.Errorf("the certificate %s does not exist", certID)
	}

	var certificate Certificate
	err = json.Unmarshal(certJSON, &certificate)
	if err != nil {
		return nil, err
	}

	return &certificate, nil
}

// CertificateExists checks if a certificate with a given ID exists in the ledger
func (s *SmartContract) CertificateExists(ctx contractapi.TransactionContextInterface, certID string) (bool, error) {
	certJSON, err := ctx.GetStub().GetState(certID)
	if err != nil {
		return false, fmt.Errorf("failed to read from world state: %v", err)
	}
	return certJSON != nil, nil
}

// GetAllCertificates returns all certificates in the world state
func (s *SmartContract) GetAllCertificates(ctx contractapi.TransactionContextInterface) ([]*Certificate, error) {
	// Get iterator for all keys in the namespace
	certificateIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, fmt.Errorf("failed to get certificate iterator: %v", err)
	}
	defer certificateIterator.Close()

	var certificates []*Certificate
	for certificateIterator.HasNext() {
		queryResponse, err := certificateIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to get next certificate: %v", err)
		}

		var certificate Certificate
		err = json.Unmarshal(queryResponse.Value, &certificate)
		if err != nil {
			return nil, fmt.Errorf("failed to unmarshal certificate: %v", err)
		}
		certificates = append(certificates, &certificate)
	}

	return certificates, nil
}

// RevokeCertificate removes a certificate from the ledger
func (s *SmartContract) RevokeCertificate(ctx contractapi.TransactionContextInterface, certID string) error {
	// Check if the certificate exists
	exists, err := s.CertificateExists(ctx, certID)
	if err != nil {
		return fmt.Errorf("failed to check if certificate exists: %v", err)
	}
	if !exists {
		return fmt.Errorf("the certificate %s does not exist", certID)
	}
	
	// Check if the caller has the right to revoke certificates (only UniversityOrg)
	clientOrgID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return fmt.Errorf("failed to get client MSP ID: %v", err)
	}

	// Only allow UniversityOrg to revoke certificates
	if clientOrgID != "Org1MSP" { // Org1MSP is UniversityOrg
		return fmt.Errorf("only UniversityOrg can revoke certificates")
	}
	
	// Delete the certificate from the world state
	return ctx.GetStub().DelState(certID)
}

func main() {
	chaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		fmt.Printf("Error creating certificate management chaincode: %v", err)
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting certificate management chaincode: %v", err)
	}
}
