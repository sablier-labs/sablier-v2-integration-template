// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { StakeSablierNFT_Fork_Test } from "../StakeSablierNFT.t.sol";

contract Unstake_Test is StakeSablierNFT_Fork_Test {
    modifier givenStaked() {
        stakingContract.stake(existingStreamId);
        _;
    }

    function test_RevertWhen_CallerNotStaker() external givenStaked {
        address unauthorizedCaller = makeAddr("Unauthorized");
        // Change the caller to an unauthorized address
        vm.startPrank({ msgSender: unauthorizedCaller });

        vm.expectRevert(abi.encodeWithSelector(NotStreamOwner.selector, unauthorizedCaller, existingStreamId));
        stakingContract.unstake(existingStreamId);
    }

    modifier whenCallerIsStaker() {
        _;
    }

    function test_Unstake() external whenCallerIsStaker givenStaked {
        // Move the time forward by 1000 seconds
        vm.warp(block.timestamp + 1000 seconds);

        // Expect {Unstaked} event to be emitted by the staking contract
        vm.expectEmit({ emitter: address(stakingContract) });
        emit Unstaked(staker, existingStreamId);

        // Unstake the NFT
        stakingContract.unstake(existingStreamId);

        // Assert: staker is the new owner of the NFT
        assertEq(sablier.ownerOf(existingStreamId), staker);

        // Assert: `streamOwner` has been deleted from storage
        assertEq(stakingContract.streamOwner(existingStreamId), address(0));

        // Assert: `claimAmount` equals expected amount
        uint256 tokensInStream;
        if (sablier.isCancelable(existingStreamId)) {
            tokensInStream =
                sablier.withdrawableAmountOf(existingStreamId) + sablier.refundableAmountOf(existingStreamId);
        } else {
            tokensInStream = sablier.getDepositedAmount(existingStreamId) - sablier.getWithdrawnAmount(existingStreamId);
        }
        uint256 expectedReward = (tokensInStream * 1000 * rewardRate) / 1e18;
        assertEq(stakingContract.stakingRewards(existingStreamId), expectedReward);
    }
}
