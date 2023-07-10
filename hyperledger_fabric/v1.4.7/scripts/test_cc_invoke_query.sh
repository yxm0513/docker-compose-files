#!/bin/bash

# Importing useful functions for cc testing
if [ -f ./func.sh ]; then
 source ./func.sh
elif [ -f scripts/func.sh ]; then
 source scripts/func.sh
fi

CC_NAME=${CC_NAME:-$CC_02_NAME}
CC_INVOKE_ARGS=${CC_INVOKE_ARGS:-$CC_02_INVOKE_ARGS}
CC_QUERY_ARGS=${CC_QUERY_ARGS:-$CC_02_QUERY_ARGS}

#Query on chaincode on Peer0/Org1
echo_b "=== Testing Chaincode invoke/query ==="

# Non-side-DB testing
echo_b "Query chaincode ${CC_NAME} on peer org1/peer0..."
chaincodeQuery 1 0 "${ORG1_PEER0_URL}" "${ORG1_PEER0_TLS_ROOTCERT}" ${APP_CHANNEL} ${CC_NAME} ${CC_QUERY_ARGS} 100

#Invoke on chaincode on Peer0/Org1
echo_b "Invoke transaction (transfer 10) by org1/peer0..."
chaincodeInvoke 1 0 "${ORG1_PEER0_URL}" "${ORG1_PEER0_TLS_ROOTCERT}" ${APP_CHANNEL} "${ORDERER0_URL}" ${ORDERER0_TLS_ROOTCERT} ${CC_NAME} ${CC_INVOKE_ARGS}

#Query on chaincode on Peer1/Org2, check if the result is 90
echo_b "Query chaincode on org2/peer1..."
chaincodeQuery 2 1 "${ORG1_PEER0_URL}" "${ORG1_PEER0_TLS_ROOTCERT}" ${APP_CHANNEL} ${CC_NAME} ${CC_QUERY_ARGS} 90

#Invoke on chaincode on Peer1/Org2
echo_b "Send invoke transaction on org2/peer1..."
chaincodeInvoke 2 1 "${ORG1_PEER0_URL}" "${ORG1_PEER0_TLS_ROOTCERT}" ${APP_CHANNEL} "${ORDERER0_URL}" ${ORDERER0_TLS_ROOTCERT} ${CC_NAME} ${CC_INVOKE_ARGS}

#Query on chaincode on Peer1/Org2, check if the result is 80
echo_b "Query chaincode on org1/peer0..."
chaincodeQuery 1 0 "${ORG1_PEER0_URL}" "${ORG1_PEER0_TLS_ROOTCERT}" ${APP_CHANNEL} ${CC_NAME} ${CC_QUERY_ARGS} 80

echo_g "=== Chaincode invoke/query done ==="
