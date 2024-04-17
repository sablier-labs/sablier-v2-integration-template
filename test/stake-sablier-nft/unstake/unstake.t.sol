// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { StakeSablierNFT_Fork_Test } from "../StakeSablierNFT.t.sol";

contract Unstake_Test is StakeSablierNFT_Fork_Test {
    function test_RevertWhen_CallerNotAuthorized() external {
        uint256 streamId = users.bob.streamId;

        // Change the caller to an unauthorized address.
        resetPrank({ msgSender: users.bob.addr });

        vm.expectRevert(abi.encodeWithSelector(UnauthorizedCaller.selector, users.bob.addr, streamId));
        stakingContract.unstake(streamId);
    }

    modifier whenCallerIsAuthorized() {
        _;
    }

    modifier givenStaked() {
        uint256 streamId = users.staker.streamId;
        stakingContract.stake(streamId);
        vm.warp(block.timestamp + 1 days);
        _;
    }

    function test_Unstake() external whenCallerIsAuthorized givenStaked {
        // Expect {Unstaked} event to be emitted.
        vm.expectEmit({ emitter: address(stakingContract) });
        emit Unstaked(users.staker.addr, users.staker.streamId);

        // Unstake the NFT.
        stakingContract.unstake(users.staker.streamId);

        // Assert: NFT has been transferred.
        assertEq(SABLIER.ownerOf(users.staker.streamId), users.staker.addr);

        // Assert: `stakedAssets` and `stakedTokenId` have been deleted from storage.
        assertEq(stakingContract.stakedAssets(users.staker.streamId), address(0));
        assertEq(stakingContract.stakedTokenId(users.staker.addr), 0);

        // Assert: `totalERC20StakedSupply` has been updated.
        assertEq(stakingContract.totalERC20StakedSupply(), 0);

        // Assert: `updateReward` has correctly updated the storage variables.
        uint256 expectedReward = 1 days * rewardRate;
        assertApproxEqAbs(stakingContract.rewards(users.staker.addr), expectedReward, 0.0001e18);
        assertEq(stakingContract.lastUpdateTime(), block.timestamp);
        assertEq(stakingContract.totalRewardPaidPerERC20Token(), (expectedReward * 1e18) / tokenAmountsInStream);
        assertEq(
            stakingContract.userRewardPerERC20Token(users.staker.addr), (expectedReward * 1e18) / tokenAmountsInStream
        );
    }
}
