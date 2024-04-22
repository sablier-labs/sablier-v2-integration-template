// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { StakeSablierNFT_Fork_Test } from "../StakeSablierNFT.t.sol";

contract Stake_Test is StakeSablierNFT_Fork_Test {
    function test_RevertWhen_CallerNotStreamOwner() external {
        address unauthorizedCaller = makeAddr("Unauthorized");

        // Change the caller to an unauthorized address
        vm.startPrank({ msgSender: unauthorizedCaller });

        vm.expectRevert(abi.encodeWithSelector(NotStreamOwner.selector, unauthorizedCaller, existingStreamId));
        stakingContract.stake(existingStreamId);
    }

    modifier whenCallerIsStreamOwner() {
        _;
    }

    function test_RevertWhen_StreamingTokenIsNotRewardToken() external whenCallerIsStreamOwner {
        // Use a stream ID with different streaming asset
        existingStreamId = 1000;

        // Tranfer the stream to the staker for the test
        address ownerOfStream = sablier.ownerOf(existingStreamId);
        vm.startPrank({ msgSender: ownerOfStream });
        sablier.transferFrom({ from: ownerOfStream, to: staker, tokenId: existingStreamId });

        // Change the caller to the staker again
        vm.startPrank({ msgSender: staker });

        vm.expectRevert(abi.encodeWithSelector(InvalidToken.selector, sablier.getAsset(existingStreamId), token));
        stakingContract.stake(existingStreamId);
    }

    modifier whenStreamingTokenIsRewardToken() {
        _;
    }

    function test_Stake() external whenCallerIsStreamOwner whenStreamingTokenIsRewardToken {
        // Expect emit
        vm.expectEmit({ emitter: address(stakingContract) });
        emit Staked(staker, existingStreamId);

        // Stake the NFT
        stakingContract.stake(existingStreamId);

        // Assertions
        assertEq(sablier.ownerOf(existingStreamId), address(stakingContract));
        assertEq(stakingContract.streamOwner(existingStreamId), staker);
    }
}
