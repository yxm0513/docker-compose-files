# Makefile to bootup the network, and do testing with channel, chaincode
# Run `make test` will pass all testing cases, and delete the network
# Run `make ready` will create a network, pass testing cases, and stand there for manual test, e.g., make test_channel_list


# support advanced bash grammar
SHELL:=/bin/bash

# mode of the network: raft only for 2.x
HLF_MODE ?= raft

# mode of db: golevel, couchdb
DB_MODE ?= golevel

# mode of dev
DEV_MODE ?= non-dev

NETWORK_INIT_WAIT ?= 2 # time to wait the fabric network finish initialization

COMPOSE_FILE ?= "docker-compose-2orgs-4peers-raft.yaml"

ifeq ($(HLF_MODE),raft)
	NETWORK_INIT_WAIT=5
else
	NETWORK_INIT_WAIT=30
endif

COMPOSE_FILE="docker-compose-2orgs-4peers-$(HLF_MODE).yaml"

LOG_PATH ?= $(HLF_MODE)/logs

ifeq ($(DB_MODE),couchdb)
	COMPOSE_FILE="docker-compose-2orgs-4peers-couchdb.yaml"
endif

ifeq ($(DEV_MODE),dev)
	COMPOSE_FILE="docker-compose-2orgs-4peers-dev.yaml"
endif

all: test

test:
	@echo "Run test with $(COMPOSE_FILE)"
	@echo "Please make sure u have setup Docker and pulled images by 'make setup download'."
	make ready  # Run all testing till ready

	make stop clean

ready: # create/join channel, install/instantiate cc
	make stop

	# make clean_config_channel # Remove existing channel artifacts
	make gen_config_crypto  # Will ignore if local config path exists
	make gen_config_channel  # Will ignore if local config path exists

	make start

	sleep ${NETWORK_INIT_WAIT}

	make channel_test

	make update_anchors

	make cc_test # test_cc_install test_cc_approveformyorg test_cc_checkcommitreadiness test_cc_commit test_cc_querycommitted test_cc_invoke_query

	# make test_lscc # test lscc operations, in v2.0, legacy lscc won't work
	make test_qscc # test qscc operations
	make test_cscc # test cscc operations

	make test_fetch_blocks # fetch block files

	make test_gen_add_org3_tx
	make test_channel_update

	make test_fetch_blocks # fetch block files again
	make test_configtxlator

	make test_channel_list
	make test_channel_getinfo

	# make logs_save

	@echo "Now the fabric network is ready to play"
	@echo "* run 'make cli' to enter into the fabric-cli container."
	@echo "* run 'make stop' when done."

# channel related operations
channel_test: test_channel_create test_channel_join test_channel_list test_channel_getinfo

# chaincode related operations
cc_test: test_cc_install test_cc_queryinstalled test_cc_approveformyorg test_cc_queryapproved test_cc_checkcommitreadiness test_cc_commit test_cc_querycommitted test_cc_invoke_query

restart: stop start

start: # bootup the fabric network
	@echo "Start a fabric network with ${COMPOSE_FILE}..."
	@make clean
	@echo "Make sure the local hlf_net docker bridge exists"
	docker network ls|grep hlf_net > /dev/null || docker network create hlf_net
	@docker-compose -f ${COMPOSE_FILE} up -d  # Start a fabric network

stop: # stop the fabric network
	@echo "Stop the fabric network with ${COMPOSE_FILE}..."
	@docker-compose -f ${COMPOSE_FILE} down >& /tmp/docker-compose.log

chaincode_dev: restart chaincode_init test_cc_peer0 stop

################## Channel testing operations ################

test_channel_list: # List the channel that peer joined
	@echo "List the joined channels"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_channel_list.sh"

test_channel_getinfo: # Get info of a channel
	@echo "Get info of the app channel"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_channel_getinfo.sh"

test_channel_create: # Init the channel
	@echo "Create channel on the fabric network"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_channel_create.sh"

test_channel_join: # Init the channel
	@echo "Join channel"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_channel_join.sh"

update_anchors: # Update the anchor peer
	@echo "Update anchors on the fabric network"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_update_anchors.sh"

test_channel_update: # send the channel update transaction
	@echo "Test channel update with adding new org"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_channel_update.sh"

################## Configtxlator testing operations ################
test_configtxlator: # Test change config using configtxlator
	@echo "Testing decoding and encoding with configtxlator"
	bash scripts/test_configtxlator.sh ${HLF_MODE}
	@echo "Flattening the json files of all blocks"
	python3 scripts/json_flatter.py ${HLF_MODE}/channel-artifacts/

test_gen_add_org3_tx: # Test change config to add new org
	bash scripts/test_gen_add_org3_tx.sh ${HLF_MODE}

################## Chaincode testing operations ################
test_cc: # test chaincode, deprecated
	if [ "$(HLF_MODE)" = "dev" ]; then \
			make test_cc_peer0; \
	else \
			make test_cc_invoke_query; \
	fi

test_cc_install: # Install the chaincode
	@echo "Install chaincode to all peers"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_install.sh"

test_cc_queryinstalled: # Query the installed chaincodes
	@echo "Query the installed chaincode"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_queryinstalled.sh"

test_cc_getinstalled: # Get the installed chaincodes package
	@echo "Get the installed chaincode package"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_getinstalled.sh"

test_cc_approveformyorg: # Approve the chaincode definition
	@echo "Approve the chaincode by all orgs"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_approveformyorg.sh"

test_cc_queryapproved: # Query the approved chaincode definition
	@echo "Query the approved status of chaincode"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_queryapproved.sh"

test_cc_checkcommitreadiness: # Query the approval status of chaincode
	@echo "Query the chaincode approval status by all orgs"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_checkcommitreadiness.sh"

test_cc_commit: # Commit the chaincode definition
	@echo "Commit the chaincode by any org"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_commit.sh"

test_cc_querycommitted: # Query the commit status of the chaincode definition
	@echo "Query the commit status of chaincode"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_querycommitted.sh"

test_cc_instantiate: # Instantiate the chaincode
	@echo "Instantiate chaincode on the fabric network"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_instantiate.sh"

test_cc_upgrade: # Upgrade the chaincode
	@echo "Upgrade chaincode on the fabric network"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_upgrade.sh"

test_cc_list: # List the chaincode
	@echo "List chaincode information (installed and instantited)"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_list.sh"

test_cc_invoke_query: # test user chaincode on all peers
	@echo "Invoke and query cc example02 on all peers"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cc_invoke_query.sh"

test_cscc: # test cscc queries
	@echo "Test CSCC query"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_cscc.sh"

test_qscc: # test qscc queries
	@echo "Test QSCC query"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_qscc.sh"

test_lscc: # test lscc quries
	@echo "Test LSCC query"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_lscc.sh"

# FIXME: docker doesn't support wildcard in cp right now
test_fetch_blocks: # test fetching channel blocks fetch
	@echo "Test fetching block files"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_fetch_blocks.sh"

test_eventsclient: # test get event notification in a loop
	@echo "Test fetching event notification"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/start_eventsclient.sh"

test_sidedb: # test sideDB/private data feature
	@echo "Test sideDB"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_sideDB.sh"

temp: # test temp instructions, used for experiment
	@echo "Test experimental instructions"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/test_temp.sh"

################## Env setup related, no need to see usually ################

setup: # setup the environment
	bash scripts/env_setup.sh # Installing Docker and Docker-Compose

check: # Check shell scripts grammar
	@echo "Check shell scripts grammar"
	[ `which shellcheck` ] && shellcheck scripts/*.sh

clean: # clean up containers and chaincode images
	@echo "Clean all HLF containers and chaincode images"
	@-docker ps -a | awk '{ print $$1,$$2 }' | grep "hyperledger/fabric" | awk '{ print $$1 }' | xargs -r -I {} docker rm -f {}
	@-docker ps -a | awk '$$2 ~ /dev-peer/ { print $$1 }' | xargs -r -I {} docker rm -f {}
	@-docker images | awk '$$1 ~ /dev-peer/ { print $$3 }' | xargs -r -I {} docker rmi -f {}
	echo "May clean the config: HLF_MODE=${HLF_MODE} make clean_config_channel"

# Clean deeply by removing all generated files: container, artifacts, credentials
purge: clean
	HLF_MODE=raft make clean_config_channel
	make clean_config_crypto

env_clean: # clean up Docker environment
	@echo "Clean all images and containers"
	bash scripts/env_clean.sh

cli: # enter the cli container
	docker exec -it fabric-cli bash

sdk_node: # enter the sdk-node container
	docker exec -it sdk-node bash

gateway_java: # enter the gateway-java container
	docker exec -it gateway-java bash

orderer: orderer0

orderer0: # enter the orderer0 container
	docker exec -it orderer0.example.com bash

orderer1: # enter the orderer0 container
	docker exec -it orderer1.example.com bash

peer: peer0

peer0: # enter the peer container
	docker exec -it peer0.org1.example.com bash

peer1: # enter the peer container
	docker exec -it peer1.org1.example.com bash

ps: # show existing docker images
	docker ps -a

logs: # show logs
	docker-compose -f ${COMPOSE_FILE} logs -f --tail 200

logs_check: logs_save logs_view

logs_save: # save logs
	@echo "All tests done, saving logs locally"
	[ -d $(LOG_PATH) ] || mkdir -p $(LOG_PATH)
	docker logs peer0.org1.example.com >& $(LOG_PATH)/dev_peer0.log
	docker logs orderer0.example.com >& $(LOG_PATH)/dev_orderer.log
	docker-compose -f ${COMPOSE_FILE} logs >& $(LOG_PATH)/dev_all.log

logs_view: # view logs
	less $(LOG_PATH)/dev_peer.log

elk: # insert logs into elk
	# curl -XDELETE http://localhost:9200/logstash-\*
	nc localhost 5000 < $(LOG_PATH)/dev_all.log

gen_config_crypto: # generate crypto config
	bash scripts/gen_crypto_artifacts.sh

gen_config_channel: # generate channel artifacts
	bash scripts/gen_channel_artifacts.sh ${HLF_MODE}

clean_config_channel: # clean channel related artifacts
	rm -rf ${HLF_MODE}/channel-artifacts/*

clean_config_crypto: # clean config artifacts
	echo "Warning: Cleaning credentials will affect artifacts in raft mode"
	rm -rf crypto-config/*
	rm -rf org3/crypto-config/*

download: # download required images
	@echo "Download Docker images"
	bash scripts/download_images.sh

################## chaincode dev mode ################
chaincode_init: # start chaincode in dev mode and do install/instantiate
	@echo "Install and instantiate cc example02 on the fabric dev network"
	@docker exec -it fabric-cli bash -c "cd /tmp; bash scripts/init_chaincode_dev.sh"
