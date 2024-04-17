// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { Broker, LockupLinear } from "@sablier/v2-core/src/types/DataTypes.sol";
import { Test } from "forge-std/src/Test.sol";

import { StakeSablierNFT } from "src/StakeSablierNFT.sol";
import { console2 } from "forge-std/src/console2.sol";

struct StreamOwner {
    address addr;
    uint256 streamId;
}

struct Users {
    // Creator of the NFT staking contract.
    address admin;
    // Alice is authorized to stake.
    StreamOwner alice;
    // Bob is unauthorized to stake.
    StreamOwner bob;
    // Staker is the user we will test the contract for.
    StreamOwner staker;
}

abstract contract StakeSablierNFT_Fork_Test is Test {
    // Errors
    error AlreadyStaking(address account, uint256 tokenId);
    error DifferentStreamingAsset(uint256 tokenId, IERC20 rewardToken);
    error ProvidedRewardTooHigh();
    error StakingAlreadyActive();
    error UnauthorizedCaller(address account, uint256 tokenId);
    error ZeroAddress(uint256 tokenId);
    error ZeroAmount();
    error ZeroDuration();

    // Events
    event RewardAdded(uint256 reward);
    event RewardDurationUpdated(uint256 newDuration);
    event RewardPaid(address indexed user, uint256 reward);
    event Staked(address indexed user, uint256 tokenId);
    event Unstaked(address indexed user, uint256 tokenId);

    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // Get the latest deployment address from the docs: https://docs.sablier.com/contracts/v2/deployments.
    ISablierV2LockupLinear internal constant SABLIER =
        ISablierV2LockupLinear(0xAFb979d9afAd1aD27C5eFf4E27226E3AB9e5dCC9);

    // Set a stream ID to stake.
    uint256 internal stakingStreamId = 2;

    // Reward rate based on the total amount staked.
    uint256 internal rewardRate;

    // Token used for creating streams as well as to distribute rewards.
    IERC20 internal rewardToken = DAI;

    StakeSablierNFT internal stakingContract;

    uint256 internal tokenAmountsInStream;

    Users internal users;

    function setUp() public {
        // Fork Ethereum Mainnet.
        vm.createSelectFork({ blockNumber: 19_689_210, urlOrAlias: "mainnet" });

        // Create users.
        users.admin = makeAddr("admin");
        users.alice.addr = makeAddr("alice");
        users.bob.addr = makeAddr("bob");
        users.staker.addr = makeAddr("staker");

        // Mint some reward tokens to the admin address which will be used to deposit to the staking contract.
        deal({ token: address(rewardToken), to: users.admin, give: 10_000e18 });

        // Make the admin the `msg.sender` in all following calls.
        vm.startPrank({ msgSender: users.admin });

        // Deploy the staking contract.
        stakingContract =
            new StakeSablierNFT({ initialAdmin: users.admin, rewardERC20Token_: rewardToken, sablierLockup_: SABLIER });

        // Fund the staking contract with some reward tokens.
        rewardToken.transfer(address(stakingContract), 10_000e18);

        // Start the staking period.
        stakingContract.startStakingPeriod(10_000e18, 1 weeks);

        // Set expected reward rate.
        rewardRate = 10_000e18 / uint256(1 weeks);

        // Stake some streams.
        _createAndStakeStreamBy({ recipient: users.alice, asset: DAI, stake: true });
        _createAndStakeStreamBy({ recipient: users.bob, asset: USDC, stake: false });
        _createAndStakeStreamBy({ recipient: users.staker, asset: DAI, stake: false });

        // Make the stream owner the `msg.sender` in all the subsequent calls.
        resetPrank({ msgSender: users.staker.addr });

        // Approve the staking contract to spend the NFT.
        SABLIER.setApprovalForAll(address(stakingContract), true);
    }

    /// @dev Stops the active prank and sets a new one.
    function resetPrank(address msgSender) internal {
        vm.stopPrank();
        vm.startPrank(msgSender);
    }

    function _createLockupLinearStreams(address recipient, IERC20 asset) private returns (uint256 streamId) {
        deal({ token: address(asset), to: users.admin, give: 1000e18 });

        resetPrank({ msgSender: users.admin });

        asset.approve(address(SABLIER), type(uint256).max);

        // Declare the params struct
        LockupLinear.CreateWithDurations memory params;

        // Declare the function parameters
        params.sender = users.admin; // The sender will be able to cancel the stream
        params.recipient = recipient; // The recipient of the streamed assets
        params.totalAmount = uint128(1000e18); // Total amount is the amount inclusive of all fees
        params.asset = asset; // The streaming asset
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.transferable = true; // Whether the stream will be transferable or not
        params.durations = LockupLinear.Durations({
            cliff: 4 weeks, // Assets will be unlocked only after 4 weeks
            total: 52 weeks // Setting a total duration of ~1 year
         });
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter for charging a fee

        // Create the Sablier stream using a function that sets the start time to `block.timestamp`
        streamId = SABLIER.createWithDurations(params);
    }

    function _createAndStakeStreamBy(StreamOwner storage recipient, IERC20 asset, bool stake) private {
        resetPrank({ msgSender: users.admin });

        uint256 streamId = _createLockupLinearStreams(recipient.addr, asset);
        recipient.streamId = streamId;

        // Make the stream owner the `msg.sender` in all the subsequent calls.
        resetPrank({ msgSender: recipient.addr });

        // Approve the staking contract to spend the NFT.
        SABLIER.setApprovalForAll(address(stakingContract), true);

        // Stake a few NFTs to simulate the actual staking behavior.
        if (stake) {
            stakingContract.stake(streamId);
        }
    }
}
