// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

// import { StakeSablierNFT_Fork_Test } from "../StakeSablierNFT.t.sol";

// contract Claim_Test is StakeSablierNFT_Fork_Test {
//     function test_RevertWhen_CallerUnauthorized() external {
//         address unauthorizedCaller = makeAddr("Unauthorized");
//         // Change the caller to an unauthorized address
//         resetPrank({ msgSender: unauthorizedCaller });

//         vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector, unauthorizedCaller, existingStreamId));
//         stakingContract.claim(existingStreamId);
//     }

//     modifier whenCallerIsAuthorized() {
//         _;
//     }

//     modifier givenStaked() {
//         stakingContract.stake(existingStreamId);

//         // Advance time in the future
//         vm.warp(block.timestamp + 1 weeks);
//         _;
//     }

//     function test_RevertWhen_ClaimAmountZero() external whenCallerIsAuthorized givenStaked {
//         // claim rewards so that claim amount becomes zero
//         stakingContract.claim(existingStreamId);

//         vm.expectRevert(abi.encodeWithSelector(ZeroAmount.selector));
//         stakingContract.claim(existingStreamId);
//     }

//     modifier whenClaimAmountNotZero() {
//         _;
//     }

//     function test_RevertWhen_ContractBalanceIsLessThanClaimAmount()
//         external
//         whenCallerIsAuthorized
//         whenClaimAmountNotZero
//         givenStaked
//     {
//         // Calculate expected rewards in 52 weeks
//         uint256 tokensInStream;
//         if (sablier.isCancelable(existingStreamId)) {
//             tokensInStream =
//                 sablier.withdrawableAmountOf(existingStreamId) + sablier.refundableAmountOf(existingStreamId);
//         } else {
//             tokensInStream = sablier.getDepositedAmount(existingStreamId) -
// sablier.getWithdrawnAmount(existingStreamId);
//         }
//         uint256 expectedReward = (tokensInStream * 53 * 7 * 24 * 3600 * rewardRate) / 1e18;

//         // Advance time in the future
//         vm.warp(block.timestamp + 52 weeks);

//         // Get the balance of the staking contract
//         uint256 balance = stakingContract.REWARD_TOKEN().balanceOf(address(stakingContract));

//         vm.expectRevert(abi.encodeWithSelector(ClaimAmountExceedsBalance.selector, expectedReward, balance));

//         // Claim rewards
//         stakingContract.claim(existingStreamId);
//     }

//     modifier whenContractBalanceIsNotLessThanClaimAmount() {
//         _;
//     }

//     function test_Claim_GivenStaked()
//         external
//         whenCallerIsAuthorized
//         whenClaimAmountNotZero
//         whenContractBalanceIsNotLessThanClaimAmount
//         givenStaked
//     {
//         // Calculate expected rewards in 1 week
//         uint256 tokensInStream;
//         if (sablier.isCancelable(existingStreamId)) {
//             tokensInStream =
//                 sablier.withdrawableAmountOf(existingStreamId) + sablier.refundableAmountOf(existingStreamId);
//         } else {
//             tokensInStream = sablier.getDepositedAmount(existingStreamId) -
// sablier.getWithdrawnAmount(existingStreamId);
//         }
//         uint256 expectedReward = (tokensInStream * 14 * 24 * 3600 * rewardRate) / 1e18;

//         // Advance time in the future
//         vm.warp(block.timestamp + 1 weeks);

//         // Expect {ClaimAmountUpdated} event to be emitted by the staking contract
//         vm.expectEmit({ emitter: address(stakingContract) });
//         emit ClaimAmountUpdated(existingStreamId);

//         // Expect {Transfer} event to be emitted by the reward token contract
//         vm.expectEmit({ emitter: address(stakingContract.REWARD_TOKEN()) });
//         emit Transfer(address(stakingContract), staker, expectedReward);

//         // Claim rewards
//         stakingContract.claim(existingStreamId);

//         // Assert: staker received the staking rewards
//         assertEq(stakingContract.stakingRewards(existingStreamId), 0);
//     }

//     modifier givenUnstaked() {
//         stakingContract.stake(existingStreamId);

//         // Advance time in the future
//         vm.warp(block.timestamp + 1 weeks);

//         stakingContract.unstake(existingStreamId);
//         _;
//     }

//     function test_RevertWhen_ClaimAmountZero_GivenUnstaked() external whenCallerIsAuthorized givenUnstaked {
//         // claim rewards so that claim amount becomes zero
//         stakingContract.claim(existingStreamId);

//         vm.expectRevert(abi.encodeWithSelector(ZeroAmount.selector));
//         stakingContract.claim(existingStreamId);
//     }

//     function test_Claim_GivenUnstaked()
//         external
//         whenCallerIsAuthorized
//         whenClaimAmountNotZero
//         whenContractBalanceIsNotLessThanClaimAmount
//         givenUnstaked
//     {
//         // Calculate expected rewards in 1 week
//         uint256 tokensInStream;
//         if (sablier.isCancelable(existingStreamId)) {
//             tokensInStream =
//                 sablier.withdrawableAmountOf(existingStreamId) + sablier.refundableAmountOf(existingStreamId);
//         } else {
//             tokensInStream = sablier.getDepositedAmount(existingStreamId) -
// sablier.getWithdrawnAmount(existingStreamId);
//         }
//         uint256 expectedReward = (tokensInStream * 7 * 24 * 3600 * rewardRate) / 1e18;

//         // Advance time in the future
//         vm.warp(block.timestamp + 1 weeks);

//         // Expect {Transfer} event to be emitted by the reward token contract
//         vm.expectEmit({ emitter: address(stakingContract.REWARD_TOKEN()) });
//         emit Transfer(address(stakingContract), staker, expectedReward);

//         // Claim rewards
//         stakingContract.claim(existingStreamId);

//         // Assert: staker received the staking rewards
//         assertEq(stakingContract.stakingRewards(existingStreamId), 0);
//     }
// }
