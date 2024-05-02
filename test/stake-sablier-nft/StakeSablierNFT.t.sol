// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { Test } from "forge-std/src/Test.sol";

import { StakeSablierNFT } from "src/StakeSablierNFT.sol";

abstract contract StakeSablierNFT_Fork_Test is Test {
    // Errors
    error DifferentStreamingAsset(uint256 tokenId, IERC20 rewardToken);
    error ERC721IncorrectOwner(address, uint256, address);
    error ProvidedRewardTooHigh();
    error StakingAlreadyActive();
    error UnauthorizedCaller(address account, uint256 tokenId);
    error ZeroAmount();
    error ZeroRewardsDuration();

    // Events
    event RewardAdded(uint256 reward);
    event RewardDurationUpdated(uint256 newDuration);
    event RewardPaid(address indexed user, uint256 reward);
    event Staked(address indexed user, uint256 tokenId);
    event Unstaked(address indexed user, uint256 tokenId);

    // Admin of staking contract
    address internal admin = payable(makeAddr("admin"));

    // Set an existing stream ID
    uint256 internal existingStreamId = 1253;

    // Token used for creating streams as well as to distribute rewards
    IERC20 internal rewardToken = IERC20(0x686f2404e77Ab0d9070a46cdfb0B7feCDD2318b0);

    // Get the latest deployment address from the docs: https://docs.sablier.com/contracts/v2/deployments
    ISablierV2LockupLinear internal sablier = ISablierV2LockupLinear(0xAFb979d9afAd1aD27C5eFf4E27226E3AB9e5dCC9);

    address internal staker;

    StakeSablierNFT internal stakingContract;

    uint256 internal tokenAmountsInStream;

    function setUp() public {
        // Fork Ethereum Mainnet
        vm.createSelectFork({ blockNumber: 19_689_210, urlOrAlias: "mainnet" });

        // Sets the staker as the owner of the NFT
        staker = sablier.ownerOf(existingStreamId);

        // Mint some reward tokens to the admin address which will be used to deposit to the staking contract
        deal({ token: address(rewardToken), to: admin, give: 1_000_000e18 });

        // Make the admin the `msg.sender` in all following calls
        vm.startPrank({ msgSender: admin });

        // Deploy the staking contract
        stakingContract =
            new StakeSablierNFT({ initialAdmin: admin, rewardERC20Token_: rewardToken, sablierContract_: sablier });

        // Fund the staking contract with some reward tokens
        rewardToken.transfer(address(stakingContract), 10_000e18);

        //Start the staking period
        stakingContract.startStakingPeriod(10_000e18, 1 weeks);

        // Make the stream owner the `msg.sender` in all the subsequent calls
        vm.startPrank({ msgSender: staker });

        // Approve the staking contract to spend the NFT
        sablier.approve(address(stakingContract), existingStreamId);

        // Store the token amounts in the stream
        tokenAmountsInStream =
            sablier.getDepositedAmount(existingStreamId) - sablier.getWithdrawnAmount(existingStreamId);
    }
}
