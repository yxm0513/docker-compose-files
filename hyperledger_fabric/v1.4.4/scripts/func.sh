#!/usr/bin/env bash

echo_r () {
    [ $# -ne 1 ] && return 0
    echo -e "\033[31m$1\033[0m"
}
echo_g () {
    [ $# -ne 1 ] && return 0
    echo -e "\033[32m$1\033[0m"
}
echo_y () {
    [ $# -ne 1 ] && return 0
    echo -e "\033[33m$1\033[0m"
}
echo_b () {
    [ $# -ne 1 ] && return 0
    echo -e "\033[34m$1\033[0m"
}

# Define those global variables
if [ -f ./variables.sh ]; then
 source ./variables.sh
elif [ -f scripts/variables.sh ]; then
 source scripts/variables.sh
else
	echo_r "Cannot find the variables.sh files, pls check"
	exit 1
fi

# Verify $1 is not 0, then output error msg $2 and exit
verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "$2"
		echo_r "=== ERROR !!! FAILED to execute End-2-End Scenario ==="
		exit 1
	fi
}

# set env to use orderOrg's identity
setOrdererEnvs () {
	export CORE_PEER_LOCALMSPID="OrdererMSP"
	export CORE_PEER_MSPCONFIGPATH=${ORDERER0_ADMIN_MSP}
	export CORE_PEER_TLS_ROOTCERT_FILE=${ORDERER0_TLS_ROOTCERT}
	#t="\${ORG${org}_PEER${peer}_URL}" && CORE_PEER_ADDRESS=`eval echo $t`
}

# Set global env variables for fabric cli, after setting:
# client is the admin as given org
# TLS root cert is configured to given peer's tls ca
# remote peer address is configured to given peer's

# CORE_PEER_LOCALMSPID=Org1MSP  # local msp id to use
# CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp  # local msp path to use
# CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt  # local trusted tls ca cert
# CORE_PEER_ADDRESS=peer0.org1.example.com:7051  # remote peer to send proposal to

# Usage: setEnvs org peer
setEnvs () {
	local org=$1  # 1 or 2
	local peer=$2  # 0 or 1
	[ -z $org ] && [ -z $peer ] && echo_r "input param invalid" && exit -1

	local t=""
	export CORE_PEER_LOCALMSPID="Org${org}MSP"
	#CORE_PEER_MSPCONFIGPATH=\$${ORG${org}_ADMIN_MSP}
	t="\${ORG${org}_PEER${peer}_URL}" && export CORE_PEER_ADDRESS=`eval echo $t`
	t="\${ORG${org}_ADMIN_MSP}" && export CORE_PEER_MSPCONFIGPATH=`eval echo $t`
	t="\${ORG${org}_PEER${peer}_TLS_ROOTCERT}" && export CORE_PEER_TLS_ROOTCERT_FILE=`eval echo $t`

	#env |grep CORE
}

# Internal func called by channelCreate
# channelCreateAction channel tx orderer_url orderer_tls_rootcert
channelCreateAction(){
	local channel=$1
	local channel_tx=$2
	local orderer_url=$3
	local orderer_tls_rootcert=$4

	if [ -z "$CORE_PEER_TLS_ENABLED" ] || [ "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create \
			-c ${channel} \
			-o ${orderer_url} \
			-f ${CHANNEL_ARTIFACTS}/${channel_tx} \
			--timeout "${TIMEOUT}s"
	else
		peer channel create \
			-c ${channel} \
			-o ${orderer_url} \
			-f ${CHANNEL_ARTIFACTS}/${channel_tx} \
			--timeout "${TIMEOUT}s" \
			--tls \
			--cafile ${orderer_tls_rootcert}
	fi
	return $?
}

# Use peer0/org1's identity to create a channel
# channelCreate APP_CHANNEL APP_CHANNEL.tx org peer orderer_url orderer_tls_rootcert
channelCreate() {
	local channel=$1
	local tx=$2
	local org=$3
	local peer=$4
	local orderer_url=$5
	local orderer_tls_rootcert=$6

	[ -z $channel ] && [ -z $tx ] && [ -z $org ] && [ -z $peer ] && echo_r "input param invalid" && exit -1

	echo "=== Create Channel ${channel} by org $org/peer $peer === "
	setEnvs $org $peer
	local rc=1
	local counter=0
	while [ ${counter} -lt ${MAX_RETRY} -a ${rc} -ne 0 ]; do
		 channelCreateAction ${channel} ${tx} ${orderer_url} ${orderer_tls_rootcert}
		 rc=$?
		 let counter=${counter}+1
		 #COUNTER=` expr $COUNTER + 1`
		 [ $rc -ne 0 ] && echo "Failed to create channel $channel, retry after 3s" && sleep 3
	done
	[ $rc -ne 0 ] && cat log.txt
	verifyResult ${rc} "Channel ${channel} creation failed"
	echo "=== Channel ${channel} is created. === "
}

# called by channelJoinWithRetry
channelJoinAction () {
	local channel=$1
	peer channel join \
		-b ${channel}.block \
		>&log.txt
}

## Sometimes Join takes time hence RETRY atleast for 5 times
channelJoinWithRetry () {
	local channel=$1
	local peer=$2
	local counter=0
	channelJoinAction ${channel}
	local rc=$?
	while [ ${counter} -lt ${MAX_RETRY} -a ${rc} -ne 0 ]; do
		echo "peer${peer} failed to join channel ${channel}, retry after 2s"
		sleep 2
		channelJoinAction ${channel}
		rc=$?
		let counter=${counter}+1
	done
	[ $rc -ne 0 ] && cat log.txt
  verifyResult ${rc} "After $MAX_RETRY attempts, peer${peer} failed to Join the Channel"
}

# Join given (by default all) peers into the channel
# channelJoin channel org peer
channelJoin () {
	local channel=$1
	local org=$2
	local peer=$3
	[ -z $channel ] && [ -z $org ] && [ -z $peer ] && echo_r "input param invalid" && exit -1

	echo "=== Join org $org/peer $peer into channel ${channel} === "
	setEnvs $org $peer
	channelJoinWithRetry ${channel} $peer
	echo "=== org $org/peer $peer joined into channel ${channel} === "
}

getShasum () {
	[ ! $# -eq 1 ] && exit 1
	shasum ${1} | awk '{print $1}'
}

# List the channel that the peer joined
# E.g., for peer 0 at org 1, will do
# channelList 1 0
channelList () {
	local org=$1
	local peer=$2
	echo "=== List the channels that org${org}/peer${peer} joined === "

	setEnvs $org $peer

	peer channel list >&log.txt
	rc=$?
	[ $rc -ne 0 ] && cat log.txt
	if [ $rc -ne 0 ]; then
		echo "=== Failed to list the channels that org${org}/peer${peer} joined === "
	else
		echo "=== Done to list the channels that org${org}/peer${peer} joined === "
	fi
}

# Get the info of specific channel, including {height, currentBlockHash, previousBlockHash}.
# E.g., for peer 0 at org 1, get info of business channel will do
# channelGetInfo businesschannel 1 0
channelGetInfo () {
	local channel=$1
	local org=$2
	local peer=$3
	echo "=== Get channel info (height, currentBlockHash, previousBlockHash) of ${channel} with id of org${org}/peer${peer} === "

	setEnvs $org $peer

	peer channel getinfo -c ${channel} >&log.txt
	rc=$?
	cat log.txt
	if [ $rc -ne 0 ]; then
		echo "=== Fail to get channel info of ${channel} with id of org${org}/peer${peer} === "
	else
		echo "=== Done to get channel info of ${channel} with id of org${org}/peer${peer} === "
	fi
}

# Fetch all blocks for a channel
# Usage: channelFetchAll channel org peer orderer_url orderer_tls_rootcert
channelFetchAll () {
	local channel=$1
	local org=$2
	local peer=$3
	local orderer_url=$4
	local orderer_tls_rootcert=$5

	echo "=== Fetch all block for channel $channel === "

	local block_file=/tmp/${channel}_newest.block
	channelFetch ${channel} $org $peer ${orderer_url} ${orderer_tls_rootcert} "newest" ${block_file}
	[ $? -ne 0 ] && exit 1
	newest_block_shasum=$(getShasum ${block_file})
	echo "fetch newest block ${block_file} with shasum=${newest_block_shasum}"

	block_file=${CHANNEL_ARTIFACTS}/${channel}_config.block
	channelFetch ${channel} $org $peer ${orderer_url} ${orderer_tls_rootcert} "config" ${block_file}
	[ $? -ne 0 ] && exit 1
	echo "fetch config block ${block_file}"

	for i in $(seq 0 16); do  # we at most fetch 16 blocks
		block_file=${CHANNEL_ARTIFACTS}/${channel}_${i}.block
		channelFetch ${channel} $org $peer ${orderer_url} ${orderer_tls_rootcert} $i ${block_file}
		[ $? -ne 0 ] && exit 1
		[ -f $block_file ] || break
		echo "fetch block $i and saved into ${block_file}"
		block_shasum=$(getShasum ${block_file})
		[ ${block_shasum} = ${newest_block_shasum} ] && { echo "Block $i is the last one for channel $channel"; break; }
	done
}

# Fetch some block from a given channel
# channelFetch channel org peer orderer_url blockNum block_file
channelFetch () {
	local channel=$1
	local org=$2
	local peer=$3
	local orderer_url=$4
	local orderer_tls_rootcert=$5
	local num=$6
	local block_file=$7
	echo "=== Fetch block $num of channel $channel === "

	#setEnvs $org $peer
	setOrdererEnvs  # system channel required id from ordererOrg
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "${CORE_PEER_TLS_ENABLED}" ] || [ "${CORE_PEER_TLS_ENABLED}" = "false" ]; then
		peer channel fetch $num ${block_file} \
			-o ${orderer_url} \
			-c ${channel}  \
			>&log.txt
	else
		peer channel fetch $num ${block_file} \
			-o ${orderer_url} \
			-c ${channel} \
			--tls \
			--cafile ${orderer_tls_rootcert}  \
			>&log.txt
	fi
	if [ $? -ne 0 ]; then
		cat log.txt
		echo_r "Fetch block $num of channel $channel failed"
		return 1
	else
		echo "=== Fetch block $num of channel $channel OK === "
		return 0
	fi
}

# Sign a channel config tx
# Usage: channelSignConfigTx channel org peer transaction
channelSignConfigTx () {
	local channel=$1
	local org=$2
	local peer=$3
	local tx=$4
	[ -z $channel ] && [ -z $tx ] && [ -z $org ] && [ -z $peer ] && echo_r "input param invalid" && exit -1
	echo "=== Sign channel config tx $tx for channel $channel by org $org/peer $peer === "
	[ -f ${CHANNEL_ARTIFACTS}/${tx} ] || { echo_r "${tx} not exist"; exit 1; }

	setEnvs $org $peer

	peer channel signconfigtx -f ${CHANNEL_ARTIFACTS}/${tx} >&log.txt
	rc=$?
	[ $rc -ne 0 ] && cat log.txt
	if [ $rc -ne 0 ]; then
		echo_r "Sign channel config tx for channel $channel by org $org/peer $peer failed"
	else
		echo "=== Sign channel config tx channel $channel by org $org/peer $peer is successful === "
	fi
}

# Update a channel config
# Usage: channelUpdate channel org peer orderer_url orderer_tls_rootcert transaction_file
channelUpdate() {
	local channel=$1
	local org=$2
	local peer=$3
	local orderer_url=$4
	local orderer_tls_rootcert=$5
	local tx=$6
	[ -z $channel ] && [ -z $tx ] && [ -z $org ] && [ -z $peer ] && echo_r "input param invalid" && exit -1

	setEnvs $org $peer
	echo "=== Update config on channel ${channel} === "
	[ -f ${CHANNEL_ARTIFACTS}/${tx} ] || { echo_r "${tx} not exist"; exit 1; }
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel update \
		-c ${channel} \
		-o ${orderer_url} \
		-f ${CHANNEL_ARTIFACTS}/${tx} \
		>&log.txt
	else
		peer channel update \
		-c ${channel} \
		-o ${orderer_url} \
		-f ${CHANNEL_ARTIFACTS}/${tx} \
		--tls \
		--cafile ${orderer_tls_rootcert} \
		>&log.txt
	fi
	rc=$?
	[ $rc -ne 0 ] && cat log.txt
	verifyResult $rc "peer channel update failed"
	echo "=== Channel ${channel} is updated. === "
	sleep 2
}

# Install chaincode on the peer node
# In v2.x it will package, install and approve
# chaincodeInstall peer cc_name version path [lang]
chaincodeInstall () {
	if [ "$#" -lt 7 ]; then
		echo_r "Wrong param number for chaincode install"
		exit -1
	fi
	local org=$1
	local peer=$2
	local peer_url=$3
	local peer_tls_root_cert=$4
	local name=$5
	local version=$6
	local path=$7
	local lang="golang"
	if [ "$#" -eq 8 ]; then
    local lang=$8
  fi

	[ -z $org ] && [ -z $peer ] && [ -z $name ] && [ -z $version ] && [ -z $path ] &&  echo_r "input param invalid" && exit -1
	echo "=== Install Chaincode on org ${org}/peer ${peer} === "
	echo "name=${name}, version=${version}, path=${path}"
	setEnvs $org $peer
	peer chaincode install \
		-n ${name} \
		-v $version \
		-p ${path} \
		-l ${lang} \
		>&log.txt

	rc=$?
	[ $rc -ne 0 ] && cat log.txt
	verifyResult $rc "Chaincode installation on remote org ${org}/peer$peer has Failed"
	echo "=== Chaincode is installed on org ${org}/peer $peer === "
}

# Approve the chaincode definition
# chaincodeApprove channel org peer peer_url peer_tls_root_cert orderer_url orderer_tls_rootcert channel name version
chaincodeApprove () {
	if [ "$#" -ne 9 -a "$#" -ne 11 ]; then
		echo_r "Wrong param number for chaincode approve"
		exit -1
	fi
	local org=$1
	local peer=$2
	local peer_url=$3
	local peer_tls_root_cert=$4
	local orderer_url=$5
	local orderer_tls_rootcert=$6
	local channel=$7
	local name=$8
	local version=$9
	local collection_config=""  # collection config file path for sideDB
	local policy="OR ('Org1MSP.member','Org2MSP.member')"  # endorsement policy

	if [ ! -z "${10}" ]; then
		collection_config=${10}
	fi

	if [ ! -z "${11}" ]; then
		policy=${12}
	fi

	setEnvs $org $peer
	echo "querying installed chaincode and get its package id"
	peer lifecycle chaincode queryinstalled >&query.log
	cat query.log
	local label=${name}
	#package_id=$(grep -o "${name}_${version}:[a-z0-9]*" query.log|cut -d ":" -f 2)
	package_id=$(grep -o "${label}:[a-z0-9]*" query.log)
	echo "Approve package id=${package_id} by Org ${org}/Peer ${peer}"

	# use the --init-required flag to request the ``Init`` function be invoked to initialize the chaincode
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer lifecycle chaincode approveformyorg \
			--peerAddresses ${peer_url} \
			--channelID ${channel} \
			--name ${name} \
			--version ${version} \
			--init-required \
            --package-id ${package_id} \
			--sequence 1 \
			--signature-policy "${policy}" \
			--waitForEvent \
            --orderer ${orderer_url} >&log.txt
	else
		peer lifecycle chaincode approveformyorg \
			--peerAddresses ${peer_url} \
			--tlsRootCertFiles ${peer_tls_root_cert} \
			--channelID ${channel} \
			--name ${name} \
			--version ${version} \
			--init-required \
			--package-id ${package_id} \
			--sequence 1 \
			--signature-policy "${policy}" \
			--waitForEvent \
			--orderer ${orderer_url} \
			--tls true \
			--cafile ${orderer_tls_rootcert} >&log.txt
	fi

	rc=$?
	[ $rc -ne 0 ] && cat log.txt
	verifyResult $rc "Chaincode Approval on remote org ${org}/peer$peer has Failed"
	echo "=== Chaincode is approved on remote peer$peer === "
}

# Query the Approve the chaincode definition
# chaincodeQueryApprove channel org peer name version
chaincodeQueryApprove () {
	if [ "$#" -ne 7 ]; then
		echo_r "Wrong param number for chaincode queryapproval"
		exit -1
	fi
	local org=$1
	local peer=$2
	local peer_url=$3
	local peer_tls_root_cert=$4
	local channel=$5
	local name=$6
	local version=$7

	setEnvs $org $peer

	echo "Query the approval status of the  chaincode $name $version"
	peer lifecycle chaincode queryapprovalstatus \
		--peerAddresses ${peer_url} \
		--tlsRootCertFiles ${peer_tls_root_cert} \
		--channelID ${channel} \
		--name ${name} \
		--version ${version}
	rc=$?
	[ $rc -ne 0 ] && cat log.txt
	verifyResult $rc "ChaincodeQueryApproval Failed: org ${org}/peer$peer"
}

# Anyone can commit the chaincode definition once it's approved by major
# chaincodeCommit org peer channel orderer_url orderer_tls_rootcert name version [collection-config] [endorse-policy]
chaincodeCommit () {
	if [ "$#" -ne 7 -a "$#" -ne 9 ]; then
		echo_r "Wrong param number for chaincode commit"
		exit -1
	fi
	local org=$1
	local peer=$2
	local channel=$3
	local orderer_url=$4
	local orderer_tls_rootcert=$5
	local name=$6
	local version=$7
	local collection_config=""  # collection config file path for sideDB
	local policy="OR ('Org1MSP.member','Org2MSP.member')"  # endorsement policy

	if [ ! -z "$8" ]; then
		collection_config=$8
	fi

	if [ ! -z "$9" ]; then
		policy=$9 # chaincode endorsement policy
	fi

	setEnvs $org $peer
	echo "querying installed chaincode and get its package id"
	peer lifecycle chaincode queryinstalled >&query.log
	label=${name}
	#package_id=$(grep -o "${name}_${version}:[a-z0-9]*" query.log|cut -d ":" -f 2)
	package_id=$(grep -o "${label}:[a-z0-9]*" query.log)

	echo "Committing package id=${package_id} by Org ${org}/Peer ${peer}"
	# use the --init-required flag to request the ``Init`` function be invoked to initialize the chaincode
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer lifecycle chaincode commit \
			-o ${orderer_url} \
			--channelID ${channel} \
			--name ${name} \
			--version ${version} \
			--init-required \
			--sequence 1 \
			--peerAddresses ${ORG1_PEER0_URL} \
            --tlsRootCertFiles ${ORG1_PEER0_TLS_ROOTCERT} \
            --peerAddresses ${ORG2_PEER0_URL} \
            --tlsRootCertFiles ${ORG2_PEER0_TLS_ROOTCERT} \
			--waitForEvent \
			--collections-config "${collection_config}" \
			--signature-policy "${policy}"
	else
		peer lifecycle chaincode commit \
			-o ${orderer_url} \
			--channelID ${channel} \
			--name ${name} \
			--version ${version} \
			--init-required \
			--sequence 1 \
			--peerAddresses ${ORG1_PEER0_URL} \
            --tlsRootCertFiles ${ORG1_PEER0_TLS_ROOTCERT} \
            --peerAddresses ${ORG2_PEER0_URL} \
            --tlsRootCertFiles ${ORG2_PEER0_TLS_ROOTCERT} \
			--waitForEvent \
			--collections-config "${collection_config}" \
			--signature-policy "${policy}" \
			--tls true \
			--cafile ${orderer_tls_rootcert} >&log.txt
	fi
	rc=$?
	[ $rc -ne 0 ] && cat log.txt
	verifyResult $rc "Chaincode Commit on remote org ${org}/peer$peer has Failed"
	echo "=== Chaincode is committed on channel $channel === "
}

# Query the Commit the chaincode definition
# chaincodeQueryCommitted org peer peer_url peer_tls_root_cert channel cc_name
chaincodeQueryCommitted () {
	if [ "$#" -ne 6 ]; then
		echo_r "Wrong param number for chaincode querycommit"
		exit -1
	fi
	local org=$1
	local peer=$2
	local peer_url=$3
	local peer_tls_root_cert=$4
	local channel=$5
	local name=$6

	setEnvs $org $peer

	echo "Query the committed status of chaincode $name with ${ORG1_PEER0_URL} "
	peer lifecycle chaincode querycommitted \
			--peerAddresses ${peer_url} \
      --tlsRootCertFiles ${peer_tls_root_cert} \
			--channelID ${channel} \
			--name ${name}
	rc=$?
	[ $rc -ne 0 ] && cat log.txt
	verifyResult $rc "ChaincodeQueryCommit Failed: org ${org}/peer$peer"
}


# Instantiate chaincode on specifized peer node
# chaincodeInstantiate channel org peer orderer_url name version args
chaincodeInstantiate () {
	if [ "$#" -gt 9 -a "$#" -lt 7 ]; then
		echo_r "Wrong param number for chaincode instantaite"
		exit -1
	fi
	local channel=$1
	local org=$2
	local peer=$3
	local orderer_url=$4
	local name=$5
	local version=$6
	local args=$7
	local collection_config=""  # collection config file path for sideDB
	local policy="OR ('Org1MSP.member','Org2MSP.member')"  # endorsement policy

	if [ ! -z "$8" ]; then
		collection_config=$8
	fi

	if [ ! -z "$9" ]; then
		policy=$9
	fi

	setEnvs $org $peer
	echo "=== chaincodeInstantiate for channel ${channel} on org $org/peer $peer ===="
	echo "name=${name}, version=${version}, args=${args}, collection_config=${collection_config}, policy=${policy}"
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate \
			-o ${orderer_url} \
			-C ${channel} \
			-n ${name} \
			-v ${version} \
			-c ${args} \
			-P "${policy}" \
			--collections-config "${collection_config}" \
			>&log.txt
	else
		peer chaincode instantiate \
			-o ${orderer_url} \
			-C ${channel} \
			-n ${name} \
			-v ${version} \
			-c ${args} \
			-P "${policy}" \
			--collections-config "${collection_config}" \
			--tls \
			--cafile ${ORDERER0_TLS_CA} \
			>&log.txt
	fi
	rc=$?
	[ $rc -ne 0 ] && cat log.txt
	verifyResult $rc "ChaincodeInstantiation on org $org/peer$peer in channel ${channel} failed"
	echo "=== Chaincode Instantiated in channel ${channel} by peer$peer ==="
}

# Invoke the Init func of chaincode to start the container
# Usage: chaincodeInit org peer channel orderer name args peer_url peer_org_tlsca
chaincodeInit () {
	if [ "$#" -ne 8 ]; then
		echo_r "Wrong param number for chaincode Init"
		exit -1
	fi
	local org=$1
	local peer=$2
	local channel=$3
	local orderer=$4
	local name=$5
	local args=$6
	local peer_url=$7
	local peer_org_tlsca=$8

	[ -z $channel ] && [ -z $org ] && [ -z $peer ] && [ -z $name ] && [ -z $args ] &&  echo_r "input param invalid" && exit -1
	echo "=== chaincodeInit to orderer by id of org${org}/peer${peer} === "
	echo "channel=${channel}, name=${name}, args=${args}"
	setEnvs $org $peer
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke \
			-o ${orderer} \
			--channelID ${channel} \
			--name ${name} \
			--peerAddresses ${peer_url} \
            --tlsRootCertFiles ${peer_org_tlsca} \
			--isInit \
			-c ${args} \
			>&log.txt
	else
		peer chaincode invoke \
			-o ${orderer} \
			--channelID ${channel} \
			--name ${name} \
			--peerAddresses ${peer_url} \
            --tlsRootCertFiles ${peer_org_tlsca} \
			--isInit \
			-c ${args} \
			--tls \
			--cafile ${ORDERER0_TLS_CA} \
			>&log.txt
	fi
	rc=$?
	[ $rc -ne 0 ] && cat log.txt
	verifyResult $rc "Chaincode Init failed: peer$peer in channel ${channel}"
	echo "=== Chaincode Init done: peer$peer in channel ${channel} === "
}

# Usage: chaincodeInvoke org peer channel orderer name args peer_url peer_org_tlsca
chaincodeInvoke () {
	if [ "$#" -ne 9 ]; then
		echo_r "Wrong param number for chaincode Invoke"
		exit -1
	fi
	local org=$1
	local peer=$2
	local peer_url=$3
	local peer_org_tlsca=$4
	local channel=$5
	local orderer_url=$6
	local orderer_tls_rootcert=$7
	local name=$8
	local args=$9

	[ -z $channel ] && [ -z $org ] && [ -z $peer ] && [ -z $name ] && [ -z $args ] &&  echo_r "input param invalid" && exit -1
	echo "=== chaincodeInvoke to orderer by id of org${org}/peer${peer} === "
	echo "channel=${channel}, name=${name}, args=${args}"
	setEnvs $org $peer
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke \
			-o ${orderer_url} \
			--channelID ${channel} \
			--name ${name} \
			--peerAddresses ${peer_url} \
            --tlsRootCertFiles ${peer_org_tlsca} \
			-c ${args} \
			>&log.txt
	else
		peer chaincode invoke \
			-o ${orderer_url} \
			--channelID ${channel} \
			--name ${name} \
			--peerAddresses ${peer_url} \
            --tlsRootCertFiles ${peer_org_tlsca} \
			-c ${args} \
			--tls \
			--cafile ${orderer_tls_rootcert} \
			>&log.txt
	fi
	rc=$?
	[ $rc -ne 0 ] && cat log.txt
	verifyResult $rc "Invoke execution on peer$peer failed "
	echo "=== Invoke transaction on peer$peer in channel ${channel} is successful === "
}

# query org peer channel name args expected_result
chaincodeQuery () {
	if [ "$#" -ne 7 -a "$#" -ne 8 ]; then
		echo_r "Wrong param number $# for chaincode Query"
		echo $*
		exit -1
	fi
	local org=$1
	local peer=$2
	local peer_url=$3
	local peer_org_tlsca=$4
	local channel=$5
	local name=$6
	local args=$7
	local expected_result=""

	[ $# -eq 8 ] && local expected_result=$8

	[ -z $channel ] && [ -z $org ] && [ -z $peer ] && [ -z $name ] && [ -z $args ] &&  echo_r "input param invalid" && exit -1

	echo "=== chaincodeQuery to org $org/peer $peer === "
	echo "channel=${channel}, name=${name}, args=${args}, expected_result=${expected_result}"
	local rc=1
	local starttime=$(date +%s)

	setEnvs $org $peer

	# we either get a successful response, or reach TIMEOUT
	while [ "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0 ]; do
		echo "Attempting to Query org ${org}/peer ${peer} ...$(($(date +%s)-starttime)) secs"
		peer chaincode query \
			 -C "${channel}" \
			 -n "${name}" \
			 --peerAddresses ${peer_url} \
			 --tlsRootCertFiles ${peer_org_tlsca} \
			 -c "${args}" \
			 >&log.txt
		rc=$?
		if [ -n "${expected_result}" ]; then # need to check the result
			test $? -eq 0 && VALUE=$(cat log.txt | awk 'END {print $NF}')
			if [ "$VALUE" = "${expected_result}" ]; then
				let rc=0
				echo_b "$VALUE == ${expected_result}, passed"
			else
				let rc=1
				echo_b "$VALUE != ${expected_result}, will retry"
			fi
		fi
		if [ $rc -ne 0 ]; then
			cat log.txt
			sleep 2
		fi
	done

	# rc==0, or timeout
	if [ $rc -eq 0 ]; then
		echo "=== Query is done: org $org/peer$peer in channel ${channel} === "
	else
		echo_r "=== Query failed: org $org/peer$peer, run `make stop clean` to clean ==="
		exit 1
	fi
}

# List Installed chaincode on specified peer node, and instantiated chaincodes at specific channel
# chaincodeList org1 peer0 businesschannel
chaincodeList () {
	local org=$1
	local peer=$2
	local channel=$3

	[ -z $org ] && [ -z $peer ] && [ -z $channel ] &&  echo_r "input param invalid" && exit -1
	echo "=== ChaincodeList on org ${org}/peer ${peer} === "
	setEnvs $org $peer
	echo_b "Get installed chaincodes at peer$peer.org$org"
	peer chaincode list \
		--installed > log.txt &
	# \
	#--peerAddresses "peer${peer}.org${org}.example.com" --tls false
	rc=$?
	[ $rc -ne 0 ] && cat log.txt
  verifyResult $rc "List installed chaincodes on remote org ${org}/peer$peer has Failed"

	echo_b "Get instantiated chaincodes at channel $org"
	peer chaincode list \
		--instantiated \
		-C ${channel} > log.txt &
	rc=$?
	[ $rc -ne 0 ] && cat log.txt
  verifyResult $rc "List installed chaincodes on remote org ${org}/peer$peer has Failed"
	echo "=== ChaincodeList is done at peer${peer}.org${org} === "
}

# Start chaincode with dev mode
# TODO: use variables instead of hard-coded value
chaincodeStartDev () {
	local peer=$1
	local version=$2
	[ -z $peer ] && [ -z $version ] &&  echo_r "input param invalid" && exit -1
	setEnvs 1 0
	CORE_CHAINCODE_LOGLEVEL=debug \
	CORE_PEER_ADDRESS=peer${peer}.org1.example.com:7052 \
	CORE_CHAINCODE_ID_NAME=${CC_02_NAME}:${version} \
	nohup ./scripts/chaincode_example02 > chaincode_dev.log &
	rc=$?
	[ $rc -ne 0 ] && cat log.txt
	verifyResult $rc "Chaincode start in dev mode has Failed"
	echo "=== Chaincode started in dev mode === "
}

# chaincodeUpgrade channel org peer orderer_url name version args
chaincodeUpgrade () {
	if [ "$#" -gt 9 -a  "$#" -lt 7 ]; then
		echo_r "Wrong param number for chaincode instantaite"
		exit -1
	fi
	local channel=$1
	local org=$2
	local peer=$3
	local orderer_url=$4
	local name=$5
	local version=$6
	local args=$7
	local collection_config=""  # collection config file path for sideDB
	local policy="OR ('Org1MSP.member','Org2MSP.member')"  # endorsement policy

	echo "=== chaincodeUpgrade to orderer by id of org ${org}/peer $peer === "
	echo "name=${name}, version=${version}, args=${args}, collection_config=${collection_config}, policy=${policy}"

	setEnvs $org $peer
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode upgrade \
		-o ${orderer_url} \
		-C ${channel} \
		-n ${name} \
		-v ${version} \
		-c ${args} \
		-P "${policy}" \
		--collections-config "${collection_config}" \
		>&log.txt
	else
		peer chaincode upgrade \
		-o ${orderer_url} \
		-C ${channel} \
		-n ${name} \
		-v ${version} \
		-c ${args} \
		-P "${policy}" \
		--collections-config "${collection_config}" \
		--tls \
		--cafile ${ORDERER0_TLS_CA} \
		>&log.txt
	fi
	rc=$?
	[ $rc -ne 0 ] && cat log.txt
	verifyResult $rc "Upgrade execution on peer$peer failed "
	echo "=== Upgrade transaction on peer$peer in channel ${channel} is successful === "
}

# configtxlator encode json to pb
# Usage: configtxlatorEncode msgType input output
configtxlatorEncode() {
	local msgType=$1
	local input=$2
	local output=$3

	echo "Encode $input --> $output using type $msgType"
	docker exec -it ${CTL_CONTAINER} configtxlator proto_encode \
		--type=${msgType} \
		--input=${input} \
		--output=${output}

	#curl -sX POST \
	#		--data-binary @${input} \
	#		${CTL_ENCODE_URL}/${msgType} \
	#		>${output}
}

# configtxlator decode pb to json
# Usage: configtxlatorEncode msgType input output
configtxlatorDecode() {
	local msgType=$1
	local input=$2
	local output=$3

	echo "Config Decode $input --> $output using type $msgType"
	if [ ! -f $input ]; then
		echo_r "input file not found"
		exit 1
	fi

	docker exec -it ${CTL_CONTAINER} configtxlator proto_decode \
		--type=${msgType} \
		--input=${input} \
		--output=${output}

	#curl -sX POST \
	#	--data-binary @"${input}" \
	#	"${CTL_DECODE_URL}/${msgType}" \
	#	> "${output}"
}

# compute diff between two pb
# Usage: configtxlatorCompare channel origin updated output
configtxlatorCompare() {
	local channel=$1
	local origin=$2
	local updated=$3
	local output=$4

	echo "Config Compare $origin vs $updated > ${output} in channel $channel"
	if [ ! -f $origin ] || [ ! -f $updated ]; then
		echo_r "input file not found"
		exit 1
	fi

	docker exec -it ${CTL_CONTAINER} configtxlator compute_update \
		--original=${origin} \
		--updated=${updated} \
		--channel_id=${channel} \
		--output=${output}

	#curl -sX POST \
	#	-F channel="${channel}" \
	#	-F "original=@${origin}" \
	#	-F "updated=@${updated}" \
	#	"${CTL_COMPARE_URL}" \
	#	> "${output}"

	[ $? -eq 0 ] || echo_r "Failed to compute config update"
}

# Run cmd inside the config generator container
gen_con_exec() {
	docker exec -it $GEN_CONTAINER "$@"
}