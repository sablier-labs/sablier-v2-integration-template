// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { Script } from "forge-std/src/Script.sol";

import { CliffExponetialCreator } from "./../src/CliffExponetialCreator.sol";

contract DeployCliffExponetialCreator is Script {
    /// @dev To deploy run the CLI command:
    /// forge script script/DeployCliffExponetialCreator.s.sol --broadcast --rpc-url testnet --private-key $PRIVATE_KEY
    /// --verify --etherscan-api-key $ETHERSCAN_API_KEY
    function run() public returns (CliffExponetialCreator cliffExponetialCreator) {
        vm.startBroadcast();
        cliffExponetialCreator = new CliffExponetialCreator();
        vm.stopBroadcast();
    }
}
