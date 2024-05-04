// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { StakeSablierNFT_Fork_Test } from "../StakeSablierNFT.t.sol";

contract Stake_Test is StakeSablierNFT_Fork_Test {
    function test_RevertWhen_StreamingAssetIsNotRewardAsset() external {
        // Use a stream ID with different streaming asset
        existingStreamId = 1000;

        // Tranfer the stream to the staker for the test
        address ownerOfStream = sablier.ownerOf(existingStreamId);
        vm.startPrank({ msgSender: ownerOfStream });
        sablier.transferFrom({ from: ownerOfStream, to: staker, tokenId: existingStreamId });

        // Change the caller to the staker again
        vm.startPrank({ msgSender: staker });

        vm.expectRevert(abi.encodeWithSelector(DifferentStreamingAsset.selector, existingStreamId, rewardToken));
        stakingContract.stake(existingStreamId);
    }

    modifier whenStreamingAssetIsRewardAsset() {
        _;
    }

    function test_RevertWhen_AlreadyStaking() external whenStreamingAssetIsRewardAsset {
        // Stake the NFT.
        stakingContract.stake(existingStreamId);

        // Expect {AlreadyStaking} evenet to be emitted
        vm.expectRevert(abi.encodeWithSelector(AlreadyStaking.selector, staker, stakingContract.stakedTokenId(staker)));
        stakingContract.stake(existingStreamId);
    }

    modifier notAlreadyStaking() {
        _;
    }

    function test_Stake() external whenStreamingAssetIsRewardAsset notAlreadyStaking {
        // Expect {Staked} evenet to be emitted
        vm.expectEmit({ emitter: address(stakingContract) });
        emit Staked(staker, existingStreamId);

        // Stake the NFT
        stakingContract.stake(existingStreamId);

        // Assertions: NFT has been transferred to the staking contract
        assertEq(sablier.ownerOf(existingStreamId), address(stakingContract));

        // Assertions: storage variables
        assertEq(stakingContract.stakedAssets(existingStreamId), staker);
        assertEq(stakingContract.stakedTokenId(staker), existingStreamId);

        assertEq(stakingContract.totalERC20StakedSupply(), tokenAmountsInStream);

        // Assert: `updateReward` has correctly updated the storage variables
        assertApproxEqAbs(stakingContract.rewards(staker), 0, 0);
        assertEq(stakingContract.lastUpdateTime(), block.timestamp);
        assertEq(stakingContract.totalRewardPerERC20TokenPaid(), 0);
        assertEq(stakingContract.userRewardPerERC20Token(staker), 0);
    }
}
