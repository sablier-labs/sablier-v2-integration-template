// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { Test } from "forge-std/src/Test.sol";

import { StakeSablierNFT } from "src/StakeSablierNFT.sol";

abstract contract StakeSablierNFT_Fork_Test is Test {
    // Errors
    error ClaimAmountExceedsBalance(uint256 claimAmount, uint256 balance);
    error InvalidToken(IERC20 streamingToken, IERC20 rewardToken);
    error NotStaked(uint256 tokenId);
    error NotAuthorized(address, uint256);
    error ZeroAmount();

    // Events
    event ClaimAmountUpdated(uint256 tokenId);
    event Staked(address indexed account, uint256 indexed tokenId);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Unstaked(address indexed account, uint256 indexed tokenId);

    // Admin of staking contract
    address internal admin = payable(makeAddr("admin"));

    // Set an existing stream ID
    uint256 internal existingStreamId = 1253;

    // Set reward rate to 10%
    uint256 internal rewardRate = 3_170_979_198;

    // Get the latest deployment address from the docs: https://docs.sablier.com/contracts/v2/deployments
    ISablierV2LockupLinear internal sablier = ISablierV2LockupLinear(0xAFb979d9afAd1aD27C5eFf4E27226E3AB9e5dCC9);

    StakeSablierNFT internal stakingContract;

    address internal staker;

    // Token used for creating streams as well as to distribute rewards
    IERC20 internal token = IERC20(0x686f2404e77Ab0d9070a46cdfb0B7feCDD2318b0);

    function setUp() public {
        // Fork Ethereum Mainnet
        vm.createSelectFork({ blockNumber: 19_689_210, urlOrAlias: "mainnet" });

        // Sets the staker as the owner of the NFT
        staker = sablier.ownerOf(existingStreamId);

        // Mint some tokens to the admin address which will be used to deposit to the staking contract
        deal({ token: address(token), to: admin, give: 1_000_000e18 });

        // Make the admin the `msg.sender` in all following calls
        vm.startPrank({ msgSender: admin });

        // Deploy the staking contract
        stakingContract = new StakeSablierNFT({
            initialAdmin: admin,
            rewardRate: rewardRate,
            rewardToken: token,
            sablierLockup: sablier
        });

        // Fund the staking contract with some reward tokens
        token.transfer(address(stakingContract), 10_000e18);

        // Make the stream owner the `msg.sender` in all the subsequent calls
        vm.startPrank({ msgSender: staker });

        // Approve the staking contract to spend the NFT
        sablier.approve(address(stakingContract), existingStreamId);
    }
}
