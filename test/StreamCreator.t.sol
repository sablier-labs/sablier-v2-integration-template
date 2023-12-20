// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";

import { StreamCreator } from "../src/StreamCreator.sol";

contract StreamCreatorTest is PRBTest, StdCheats {
    // Get the latest deployment address from the docs: https://docs.sablier.com/contracts/v2/deployments
    address internal constant SABLIER_ADDRESS = address(0xAFb979d9afAd1aD27C5eFf4E27226E3AB9e5dCC9);

    // Test contracts
    StreamCreator internal creator;
    ISablierV2LockupLinear internal sablier;
    address internal user;

    function setUp() public {
        // Fork Ethereum Mainnet
        vm.createSelectFork({ blockNumber: 18_821_300, urlOrAlias: "mainnet" });

        // Load the Sablier contract from Ethereum Mainnet
        sablier = ISablierV2LockupLinear(SABLIER_ADDRESS);

        // Deploy the stream creator contract
        creator = new StreamCreator(sablier);

        // Create a test user
        user = payable(makeAddr("User"));
        vm.deal({ account: user, newBalance: 1 ether });

        // Mint some DAI tokens to the test user, which will be pulled by the creator contract
        deal({ token: address(creator.DAI()), to: user, give: 1337e18 });

        // Make the test user the `msg.sender` in all following calls
        vm.startPrank({ msgSender: user });

        // Approve the creator contract to pull DAI tokens from the test user
        creator.DAI().approve({ spender: address(creator), amount: 1337e18 });
    }

    // Test that creating streams works by checking the stream ids
    function test_CreateStream() public {
        uint256 expectedStreamId = sablier.nextStreamId();
        uint256 actualStreamId = creator.createLockupLinearStream(1337e18);
        assertEq(actualStreamId, expectedStreamId);
    }
}
