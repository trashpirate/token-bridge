-include .env

.PHONY: all test clean deploy-anvil

slither :; slither ./src 

anvil :; anvil -m 'test test test test test test test test test test test junk'

anvil-eth :; @anvil --fork-url ${RPC_MAINNET} --fork-block-number 18810000 --fork-chain-id 1 --chain-id 123
anvil-bsc :; @anvil --fork-url ${RPC_BSC} --fork-block-number 24365190 --fork-chain-id 56 --chain-id 123
anvil-base :; @anvil --fork-url ${RPC_BASE} --fork-block-number 8106000 --fork-chain-id 8453 --chain-id 123
anvil-avax :; @anvil --fork-url ${RPC_AVAX} --fork-block-number 39392000 --fork-chain-id 43114 --chain-id 123

# use the "@" to hide the command from your shell, use contract=<contract name>
deploy-testnet-sim :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account Testing --sender 0x7Bb8be3D9015682d7AC0Ea377dC0c92B0ba152eF -vv
deploy-testnet :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account Testing --sender 0x7Bb8be3D9015682d7AC0Ea377dC0c92B0ba152eF --broadcast --verify --etherscan-api-key ${network}
deploy-testnet-no-verify :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account Testing --sender 0x7Bb8be3D9015682d7AC0Ea377dC0c92B0ba152eF --broadcast

deploy-mainnet-sim :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account ${account} --sender ${sender}
deploy-mainnet-no-verify :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account ${account} --sender ${sender} --broadcast
deploy-mainnet :; @forge script script/Deploy${contract}.s.sol:Deploy${contract} --rpc-url ${network}  --account ${account} --sender ${sender} --broadcast --verify --etherscan-api-key ${network}

# verifiying
verify :; @forge create --rpc-url ${network} --constructor-args ${args} --account ${account} --etherscan-api-key ${network} --verify src/${contract}.sol:${contract}
verify-base :; @forge verify-contract --chain-id 8453 --num-of-optimizations 200 --constructor-args ${args} --etherscan-api-key ${BASESCAN_KEY} ${contractAddress} src/${contract}.sol:${contract} --watch
verify-avax-test :; @forge verify-contract --chain-id 43113 --num-of-optimizations 200 --constructor-args $(args) --etherscan-api-key "verifyContract" ${contractAddress} src/${contract}.sol:${contract} --watch --verifier-url 'https://api.routescan.io/v2/network/testnet/evm/43113/etherscan'

abi-encode :; cast abi-encode "constructor(address)" ${args}

# This is the private key of account from the mnemonic from the "make anvil" command
deploy-anvil :; @forge script script/${contract}.s.sol:Deploy${contract} --rpc-url http://localhost:8545  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast 

deploy-all :; make deploy-${network} contract=APIConsumer && make deploy-${network} contract=KeepersCounter && make deploy-${network} contract=PriceFeedConsumer && make deploy-${network} contract=VRFConsumerV2

test-fork :; @forge test --match-path test/${contract}.t.sol --rpc-url localhost

test-fork-all :; @forge test --rpc-url localhost

fuzz-test-fork :; @forge test --match-path test/fuzz/Fuzz_${contract}.t.sol --rpc-url localhost

unit-test-fork :; @forge test --match-path test/unit/${contract}.t.sol --rpc-url localhost

-include ${FCT_PLUGIN_PATH}/makefile-external