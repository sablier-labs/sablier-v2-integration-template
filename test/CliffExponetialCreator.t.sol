// SPDX-License-Identifier: GPL-3-0-or-later
pragma solidity >=0.8.19;

import { Test } from "forge-std/src/Test.sol";

import { CliffExponetialCreator } from "../src/CliffExponetialCreator.sol";

contract CliffExponetialCreatorTest is Test {
    // Test contracts
    CliffExponetialCreator internal creator;

    address internal user;

    function setUp() public {
        // Fork Ethereum Testnet
        vm.createSelectFork({ urlOrAlias: "testnet" });

        // Deploy the stream creator
        creator = new CliffExponetialCreator();

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

    function test_CreateStream_ExponentialCliff() public {
        uint256 expectedStreamId = creator.LOCKUP_DYNAMIC().nextStreamId();
        uint256 actualStreamId = creator.createStream();

        // Assert that the stream has been created.
        assertEq(actualStreamId, expectedStreamId);

        uint256 currentTime = block.timestamp;

        // Warp 50 days into the future, i.e. half way of the stream duration (unlock moment).
        vm.warp({ newTimestamp: currentTime + 50 days });

        uint128 actualStreamedAmount = creator.LOCKUP_DYNAMIC().streamedAmountOf(actualStreamId);
        uint128 expectedStreamedAmount = 20e18;
        assertEq(actualStreamedAmount, expectedStreamedAmount);

        // Warp 75 days into the future, i.e. half way of the stream's last segment.
        vm.warp({ newTimestamp: currentTime + 75 days });

        actualStreamedAmount = creator.LOCKUP_DYNAMIC().streamedAmountOf(actualStreamId);
        expectedStreamedAmount = 30e18; // 0.5^{3} * 80 + 20
        assertEq(actualStreamedAmount, expectedStreamedAmount);
    }
}
