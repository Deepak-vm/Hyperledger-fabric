#!/bin/bash

CHANNEL_NAME=$1
ORG=$2
DELAY=$3
MAX_RETRY=$4
VERBOSE=$5

# import utils
. scripts/envVar.sh
. scripts/utils.sh

if [ ! -d "channel-artifacts" ]; then
  mkdir channel-artifacts
fi

createChannelGenesisBlock() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    fatalln "configtxgen tool not found."
  fi
  
  println "Generating channel genesis block '${CHANNEL_NAME}.block'"
  
  if [ "$CHANNEL_NAME" = "bluechannel" ]; then
    PROFILE="BlueChannel"
  elif [ "$CHANNEL_NAME" = "redchannel" ]; then
    PROFILE="RedChannel"
  else
    PROFILE="TwoOrgsChannel"
  fi
  
  set -x
  configtxgen -profile ${PROFILE} -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
  res=$?
  { set +x; } 2>/dev/null
  
  verifyResult $res "Failed to generate channel config transaction..."
}

createChannel() {
  setGlobals $ORG
  # Poll until orderer is ready
  local rc=1
  local COUNTER=1
  println "Creating channel ${CHANNEL_NAME}"
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    set -x
    peer channel create -o localhost:7050 -c $CHANNEL_NAME --ordererTLSHostnameOverride orderer.example.com -f ./channel-artifacts/${CHANNEL_NAME}.tx --outputBlock ./channel-artifacts/${CHANNEL_NAME}.block --tls --cafile "$ORDERER_CA" >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  verifyResult $res "Channel creation failed"
  println "Channel '$CHANNEL_NAME' created"
}

# joinChannel ORG
joinChannel() {
  ORG=$1
  setGlobals $ORG
  
  local rc=1
  local COUNTER=1
  ## Sometimes Join takes time, hence retry
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    set -x
    peer channel join -b ./channel-artifacts/$CHANNEL_NAME.block >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  verifyResult $res "Peer$PEER.org${ORG} failed to join '$CHANNEL_NAME' channel"
  println "Peer$PEER.org${ORG} joined '$CHANNEL_NAME' channel"
}

createChannelGenesisBlock
createChannel
joinChannel 1
joinChannel 2

if [ "$CHANNEL_NAME" = "redchannel" ]; then
  println "Joining Org3 to $CHANNEL_NAME"
  
  # Set environment variables for Org3
  export CORE_PEER_LOCALMSPID="Org3MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
  export CORE_PEER_ADDRESS=localhost:11051
  
  set -x
  peer channel join -b ./channel-artifacts/${CHANNEL_NAME}.block
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Peer0.org3 failed to join '${CHANNEL_NAME}' channel"
  println "Peer0.org3 joined '${CHANNEL_NAME}' channel"
fi

println "Channel '$CHANNEL_NAME' setup completed"
