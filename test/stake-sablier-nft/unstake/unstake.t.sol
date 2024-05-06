// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { StakeSablierNFT_Fork_Test } from "../StakeSablierNFT.t.sol";

contract Unstake_Test is StakeSablierNFT_Fork_Test {
    function test_RevertWhen_CallerNotAuthorized() external {
        address unauthorizedCaller = makeAddr("Unauthorized");
        // Change the caller to an unauthorized address.
        vm.startPrank({ msgSender: unauthorizedCaller });

        vm.expectRevert(abi.encodeWithSelector(UnauthorizedCaller.selector, unauthorizedCaller, existingStreamId));
        stakingContract.unstake(existingStreamId);
    }

    modifier whenCallerIsAuthorized() {
        _;
    }

    modifier givenStaked() {
        stakingContract.stake(existingStreamId);
        vm.warp(block.timestamp + 1 days);
        _;
    }

    function test_Unstake() external whenCallerIsAuthorized givenStaked {
        // Expect {Unstaked} event to be emitted.
        vm.expectEmit({ emitter: address(stakingContract) });
        emit Unstaked(staker, existingStreamId);

        // Unstake the NFT.
        stakingContract.unstake(existingStreamId);

        // Assert: NFT has been transferred.
        assertEq(sablier.ownerOf(existingStreamId), staker);

        // Assert: `stakedAssets` and `stakedTokenId` have been deleted from storage.
        assertEq(stakingContract.stakedAssets(existingStreamId), address(0));
        assertEq(stakingContract.stakedTokenId(staker), 0);

        // Assert: `totalERC20StakedSupply` has been updated.
        assertEq(stakingContract.totalERC20StakedSupply(), 0);

        // Assert: `updateReward` has correctly updated the storage variables.
        uint256 expectedReward = 1 days * rewardRate;
        assertApproxEqAbs(stakingContract.rewards(staker), expectedReward, 0.0001e18);
        assertEq(stakingContract.lastUpdateTime(), block.timestamp);
        assertEq(stakingContract.totalRewardPerERC20TokenPaid(), (expectedReward * 1e18) / tokenAmountsInStream);
        assertEq(stakingContract.userRewardPerERC20Token(staker), (expectedReward * 1e18) / tokenAmountsInStream);
    }
}
