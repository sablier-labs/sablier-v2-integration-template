// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { Test } from "forge-std/src/Test.sol";

import { StakeSablierNFT } from "../src/StakeSablierNFT.sol";

contract StakeSablierNftTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 value);

    // Admin of staking contract
    address internal admin = payable(makeAddr("admin"));

    // Set reward rate to 10%
    uint256 internal rewardRate = 3_170_979_198;

    // Get the latest deployment address from the docs: https://docs.sablier.com/contracts/v2/deployments
    ISablierV2LockupLinear internal sablier = ISablierV2LockupLinear(0xAFb979d9afAd1aD27C5eFf4E27226E3AB9e5dCC9);

    StakeSablierNFT internal stakingContract;

    // Token used for creating streams as well as to distribute rewards
    IERC20 internal token = IERC20(0x686f2404e77Ab0d9070a46cdfb0B7feCDD2318b0);

    function setUp() public {
        // Fork Ethereum Mainnet
        vm.createSelectFork({ blockNumber: 19_689_210, urlOrAlias: "mainnet" });

        // Mint some tokens to the admin address which will be used to deposit to the staking contract
        deal({ token: address(token), to: admin, give: 1_000_000e18 });

        // Make the admin the `msg.sender` in all following calls
        vm.startPrank({ msgSender: admin });

        // Deploy the staking contract
        stakingContract = new StakeSablierNFT({
            initialAdmin: admin,
            rewardRate: rewardRate,
            rewardToken: token,
            sablierLockup: sablier
        });

        // Fund the staking contract with some reward tokens
        token.transfer(address(stakingContract), 1_000_000e18);
    }

    // Test that staking works by checking the new owner of the NFT
    function test_Stake_Claim_Unstake() public {
        // Set a valid stream ID
        uint256 tokenId = 1253;
        address user = sablier.ownerOf(tokenId);

        // Make the stream owner the `msg.sender` in all following calls
        vm.startPrank({ msgSender: user });

        /*//////////////////////////////////////////////////////////////////////////
                                        TEST STAKE
        //////////////////////////////////////////////////////////////////////////*/

        // Stake the NFT
        sablier.approve(address(stakingContract), tokenId);
        stakingContract.stake(tokenId);

        // Assert: check the initial staking contract data
        assertEq(sablier.ownerOf(tokenId), address(stakingContract));
        assertEq(stakingContract.claimAmount(tokenId), 0);
        assertEq(stakingContract.lastUpdateTimestamp(tokenId), block.timestamp);
        assertEq(stakingContract.streamOwner(tokenId), user);

        /*//////////////////////////////////////////////////////////////////////////
                                TEST UPDATE CLAIM AMOUNT
        //////////////////////////////////////////////////////////////////////////*/

        // Load the amount of total tokens in the stream
        uint256 tokensInStream = sablier.withdrawableAmountOf(tokenId) + sablier.refundableAmountOf(tokenId);

        // Move the time forward by 1000 seconds
        vm.warp(block.timestamp + 1000 seconds);

        uint256 expectedReward = (tokensInStream * 1000 * rewardRate) / 1e18;

        // Update claim amount
        stakingContract.updateClaimAmount(tokenId);

        // Assert: Check the updated staking contract data
        assertEq(stakingContract.claimAmount(tokenId), expectedReward);

        /*//////////////////////////////////////////////////////////////////////////
                                    TEST WITHDRAW REWARDS
        //////////////////////////////////////////////////////////////////////////*/

        // Verify {Transfer} event on `withdrawRewards` call
        vm.expectEmit();
        emit Transfer(address(stakingContract), user, expectedReward);

        // Claim rewards
        stakingContract.withdrawRewards(tokenId);

        // Assert: Check the updated staking contract data
        assertEq(stakingContract.claimAmount(tokenId), 0);
        assertEq(stakingContract.lastUpdateTimestamp(tokenId), block.timestamp);

        /*//////////////////////////////////////////////////////////////////////////
                                        TEST UNSTAKE
        //////////////////////////////////////////////////////////////////////////*/

        // Move the time forward by 1000 seconds
        vm.warp(block.timestamp + 1000 seconds);

        // Verify {Transfer} event on `withdrawRewards` call
        vm.expectEmit();
        emit Transfer(address(stakingContract), user, expectedReward);

        // Unstake the NFT
        stakingContract.unstake(tokenId);

        // Assert: Check the updated staking contract data
        assertEq(sablier.ownerOf(tokenId), user);
        assertEq(stakingContract.claimAmount(tokenId), 0);
        assertEq(stakingContract.lastUpdateTimestamp(tokenId), block.timestamp);
        assertEq(stakingContract.streamOwner(tokenId), address(0));
    }
}
