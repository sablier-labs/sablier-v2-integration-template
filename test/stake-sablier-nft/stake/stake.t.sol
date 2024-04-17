// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { StakeSablierNFT_Fork_Test } from "../StakeSablierNFT.t.sol";

contract Stake_Test is StakeSablierNFT_Fork_Test {
    function test_RevertWhen_StreamingAssetIsNotRewardAsset() external {
        uint256 streamId = users.bob.streamId;

        // Change the caller to the users.staker again.
        resetPrank({ msgSender: users.bob.addr });

        vm.expectRevert(abi.encodeWithSelector(DifferentStreamingAsset.selector, streamId, DAI));
        stakingContract.stake(streamId);
    }

    modifier whenStreamingAssetIsRewardAsset() {
        _;
    }

    function test_RevertWhen_AlreadyStaking() external whenStreamingAssetIsRewardAsset {
        uint256 streamId = users.staker.streamId;

        // Stake the NFT.
        stakingContract.stake(streamId);

        // Expect {AlreadyStaking} evenet to be emitted.
        vm.expectRevert(
            abi.encodeWithSelector(
                AlreadyStaking.selector, users.staker.addr, stakingContract.stakedTokenId(users.staker.addr)
            )
        );
        stakingContract.stake(streamId);
    }

    modifier notAlreadyStaking() {
        _;
    }

    function test_Stake() external whenStreamingAssetIsRewardAsset notAlreadyStaking {
        uint256 streamId = users.staker.streamId;

        // Expect {Staked} evenet to be emitted.
        vm.expectEmit({ emitter: address(stakingContract) });
        emit Staked(users.staker.addr, streamId);

        // Stake the NFT.
        stakingContract.stake(streamId);

        // Assertions: NFT has been transferred to the staking contract.
        assertEq(SABLIER.ownerOf(streamId), address(stakingContract));

        // Assertions: storage variables.
        assertEq(stakingContract.stakedAssets(streamId), users.staker.addr);
        assertEq(stakingContract.stakedTokenId(users.staker.addr), streamId);

        assertEq(stakingContract.totalERC20StakedSupply(), tokenAmountsInStream);

        // Assert: `updateReward` has correctly updated the storage variables.
        assertApproxEqAbs(stakingContract.rewards(users.staker.addr), 0, 0);
        assertEq(stakingContract.lastUpdateTime(), block.timestamp);
        assertEq(stakingContract.totalRewardPaidPerERC20Token(), 0);
        assertEq(stakingContract.userRewardPerERC20Token(users.staker.addr), 0);
    }
}
