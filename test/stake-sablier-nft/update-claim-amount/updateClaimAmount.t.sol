// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

// import { StakeSablierNFT_Fork_Test } from "../StakeSablierNFT.t.sol";

// contract UpdateClaimAmount_Test is StakeSablierNFT_Fork_Test {
//     modifier givenStaked() {
//         stakingContract.stake(existingStreamId);
//         _;
//     }

//     function test_UpdateClaimAmount_WhenUnstaked() external givenStaked {
//         // Advance time in the future
//         vm.warp(block.timestamp + 1000 seconds);

//         // Unstake the NFT
//         stakingContract.unstake(existingStreamId);

//         uint256 beforeStakingRewards = stakingContract.stakingRewards(existingStreamId);
//         uint256 beforeTimestamp = stakingContract.lastUpdateTimestamp(existingStreamId);

//         // Advance time in the future
//         vm.warp(block.timestamp + 1000 seconds);

//         // Update claim amount
//         stakingContract.updateClaimAmount(existingStreamId);

//         uint256 afterStakingRewards = stakingContract.stakingRewards(existingStreamId);
//         uint256 afterTimestamp = stakingContract.lastUpdateTimestamp(existingStreamId);

//         // Assert: values should be unchanged
//         assertEq(beforeStakingRewards, afterStakingRewards);
//         assertEq(beforeTimestamp, afterTimestamp);
//     }

//     function test_UpdateClaimAmount() external givenStaked {
//         // Calculate expected reward change in 1000 seconds
//         uint256 tokensInStream;
//         if (sablier.isCancelable(existingStreamId)) {
//             tokensInStream =
//                 sablier.withdrawableAmountOf(existingStreamId) + sablier.refundableAmountOf(existingStreamId);
//         } else {
//             tokensInStream = sablier.getDepositedAmount(existingStreamId) -
// sablier.getWithdrawnAmount(existingStreamId);
//         }
//         uint256 expectedRewardChange = (tokensInStream * 1000 * rewardRate) / 1e18;

//         // Advance time in the future
//         vm.warp(block.timestamp + 1000 seconds);

//         // Update claim amount
//         vm.expectEmit({ emitter: address(stakingContract) });
//         emit ClaimAmountUpdated(existingStreamId);
//         stakingContract.updateClaimAmount(existingStreamId);

//         uint256 beforeStakingRewards = stakingContract.stakingRewards(existingStreamId);
//         uint256 beforeTimestamp = stakingContract.lastUpdateTimestamp(existingStreamId);

//         // Advance time in the future
//         vm.warp(block.timestamp + 1000 seconds);

//         // Update claim amount
//         vm.expectEmit({ emitter: address(stakingContract) });
//         emit ClaimAmountUpdated(existingStreamId);
//         uint256 newClaimAmount = stakingContract.updateClaimAmount(existingStreamId);

//         uint256 afterStakingRewards = stakingContract.stakingRewards(existingStreamId);
//         uint256 afterTimestamp = stakingContract.lastUpdateTimestamp(existingStreamId);

//         // Assert: values should be changed
//         assertEq(afterStakingRewards, beforeStakingRewards + expectedRewardChange);
//         assertEq(afterTimestamp, beforeTimestamp + 1000 seconds);
//         assertEq(newClaimAmount, afterStakingRewards);
//     }
// }
