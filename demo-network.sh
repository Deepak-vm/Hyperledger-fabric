#!/bin/bash
# filepath: /home/hyperledger/fabric-samples/demo-network.sh

function header() {
  echo -e "\033[1;35m=============================================\033[0m"
  echo -e "\033[1;35m   $1\033[0m"
  echo -e "\033[1;35m=============================================\033[0m"
}

function subheader() {
  echo -e "\033[0;36m----- $1 -----\033[0m"
}

cd ~/fabric-samples/test-network

# 1. Show all running Docker containers
header "DOCKER CONTAINERS RUNNING IN THE NETWORK"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

# 2. Show Docker networks
header "DOCKER NETWORKS"
docker network ls | grep fabric

# 3. Show details about each peer
header "PEER ORGANIZATIONS"
subheader "Org1 MSP Structure"
ls -la organizations/peerOrganizations/org1.example.com/

subheader "Org2 MSP Structure"
ls -la organizations/peerOrganizations/org2.example.com/

subheader "Org3 MSP Structure"
ls -la organizations/peerOrganizations/org3.example.com/

# 4. Export environment variables
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/

# 5. Channel membership for Org1
header "CHANNEL MEMBERSHIP FOR EACH ORGANIZATION"
subheader "Org1 Channels"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer channel list

# 6. Channel membership for Org2
subheader "Org2 Channels"
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
peer channel list

# 7. Channel membership for Org3
subheader "Org3 Channels"
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051
peer channel list

# 8. Installed chaincodes
header "DEPLOYED CHAINCODE DETAILS"
subheader "Chaincode on Org1"
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer lifecycle chaincode queryinstalled

subheader "Chaincode on Org2"
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
peer lifecycle chaincode queryinstalled

subheader "Chaincode on Org3"
export CORE_PEER_LOCALMSPID="Org3MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051
peer lifecycle chaincode queryinstalled

# 9. Query data from each channel
header "QUERYING DATA FROM EACH CHANNEL"
subheader "Data in mychannel"
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}'

subheader "Data in bluechannel"
peer chaincode query -C bluechannel -n basic-blue -c '{"Args":["GetAllAssets"]}'

subheader "Data in redchannel"
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
peer chaincode query -C redchannel -n basic-red -c '{"Args":["GetAllAssets"]}'

# 10. Docker logs for key containers
header "RECENT LOGS FROM KEY CONTAINERS"
subheader "Orderer Logs (last 10 lines)"
docker logs orderer.example.com 2>&1 | tail -n 10

subheader "Org1 Peer Logs (last 10 lines)"
docker logs peer0.org1.example.com 2>&1 | tail -n 10 

subheader "Org2 Peer Logs (last 10 lines)"
docker logs peer0.org2.example.com 2>&1 | tail -n 10

subheader "Org3 Peer Logs (last 10 lines)"
docker logs peer0.org3.example.com 2>&1 | tail -n 10

# 11. Network diagram visualization
header "NETWORK DIAGRAM"
echo -e "\033[0;33m
┌─────────────────────────────────────────────────────────────────────┐
│                       Hyperledger Fabric Network                     │
├────────────┬────────────────────────────┬───────────────────────────┤
│            │                            │                           │
│            ▼                            ▼                           ▼
│  ┌─────────────────┐         ┌─────────────────┐        ┌─────────────────┐
│  │      Org1       │         │      Org2       │        │      Org3       │
│  └─────┬───────────┘         └────────┬────────┘        └────────┬────────┘
│        │                              │                          │
│        ▼                              ▼                          ▼
│  ┌─────────────┐               ┌─────────────┐             ┌─────────────┐
│  │ peer0.org1  │               │ peer0.org2  │             │ peer0.org3  │
│  └─────────────┘               └─────────────┘             └─────────────┘
│        │                              │                          │
│        │                              │                          │
│        │                              │                          │
│        ├──────────────────┐           │                          │
│        │  mychannel       │◄──────────┘                          │
│        └──────────────────┘                                      │
│        │                                                         │
│        ├──────────────────┐                                      │
│        │  bluechannel     │◄──────────┐                          │
│        └──────────────────┘           │                          │
│                                       │                          │
│                           ┌───────────┴──────────┐               │
│                           │     redchannel       │◄──────────────┘
│                           └──────────────────────┘
└─────────────────────────────────────────────────────────────────────┘
\033[0m"

header "NETWORK DEMONSTRATION COMPLETE"
echo -e "\033[0;32mYour multi-channel Hyperledger Fabric network is fully operational.\033[0m"