// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { Adminable } from "@sablier/v2-core/src/abstracts/Adminable.sol";
import { ISablierV2Lockup } from "@sablier/v2-core/src/interfaces/ISablierV2Lockup.sol";

/// @title StakeSablierNFT
///
/// @notice DISCLAIMER: This template has not been audited and is provided "as is" with no warranties of any kind,
/// either express or implied. It is intended solely for demonstration purposes on how to build a staking contract using
/// Sablier NFT. This template should not be used in a production environment. It makes specific assumptions that may
/// not be applicable to your particular needs.
///
/// @dev This template allows users to stake Sablier NFTs and earn staking rewards based on the total amount available
/// in the stream. The implementation is based on the Synthetix staking contract:
/// https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol
///
/// Assumptions:
///   - The Sablier NFT must be transferrable.
///   - The Sablier NFT must be non-cancelable.
///   - One user can only stake one NFT at a time.
///
/// Risks:
///   - If you want to implement the staking for CANCELABLE streams, be careful with how you calculate the amount in
/// streams.
///   If the stream is not cancelable:
///     - the tokens in the stream are the difference between the amount deposited and the amount withdrawn
///         amountInStream = sablierLockup.getDepositedAmount(tokenId) - sablierLockup.getWithdrawnAmount(tokenId);
///
///   If the stream is cancelable:
///     - If not canceled, the tokens in the stream are the sum of amount available to withdraw and the amount that
///       can be refunded to the sender:
///
///         amountInStream = sablierLockup.withdrawableAmountOf(tokenId) +
/// sablierLockup.refundableAmountOf(tokenId);
///
///     - If canceled, the tokens in the stream are the difference between the amount deposited, the amount
///       withdrawn and the amount refunded.
///
///         amountInStream = sablierLockup.getDepositedAmount(tokenId) - sablierLockup.getWithdrawnAmount(tokenId) -
/// sablierLockup.getRefundedAmount(tokenId);
contract StakeSablierNFT is Adminable, ERC721Holder {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                       ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error ActiveStaker(address account, uint256 tokenId);
    error DifferentStreamingAsset(uint256 tokenId, IERC20 rewardToken);
    error ProvidedRewardTooHigh();
    error StakingAlreadyActive();
    error UnauthorizedCaller(address account, uint256 tokenId);
    error ZeroAddress(uint256 tokenId);
    error ZeroAmount();
    error ZeroDuration();

    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event RewardAdded(uint256 reward);
    event RewardDurationUpdated(uint256 newDuration);
    event RewardPaid(address indexed user, uint256 reward);
    event Staked(address indexed user, uint256 tokenId);
    event Unstaked(address indexed user, uint256 tokenId);

    /*//////////////////////////////////////////////////////////////////////////
                                USER-FACING STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev The last time when rewards were updated.
    uint256 public lastUpdateTime;

    /// @dev The timestamp when the staking ends.
    uint256 public periodFinish;

    /// @dev This should be your own ERC20 token in which the staking rewards will be distributed.
    IERC20 public rewardERC20Token;

    /// @dev Earned rewards for each account.
    mapping(address account => uint256 earned) public rewards;

    /// @dev The amount of rewards per ERC20 token already distributed.
    uint256 public rewardPerERC20TokenStored;

    /// @dev Total rewards to be distributed per second.
    uint256 public rewardRate;

    /// @dev Duration for which staking is live.
    uint256 public rewardsDuration;

    /// @dev This should be the Sablier Lockup contract.
    ///   - If you used Lockup Linear, you should use the LockupLinear contract address.
    ///   - If you used Lockup Dynamic, you should use the LockupDynamic contract address.
    ISablierV2Lockup public sablierLockup;

    /// @dev The owner of the streams mapped by tokenId.
    mapping(uint256 tokenId => address account) public stakedAssets;

    /// @dev The staked token ID mapped by each account.
    mapping(address account => uint256 tokenId) public stakedTokenId;

    /// @dev The total amount of ERC20 tokens staked through Sablier NFTs.
    uint256 public totalERC20StakedSupply;

    /// @dev The rewards paid to each account per ERC20 token mapped by the account.
    mapping(address account => uint256 paidAmount) public userRewardPerERC20TokenPaid;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Modifier used to keep track of the earned rewards for user each time a `stake`, `unstake` or
    /// `claimRewards` is called.
    modifier updateReward(address account) {
        rewardPerERC20TokenStored = rewardPerERC20Token();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = calculateRewards(account);
            userRewardPerERC20TokenPaid[account] = rewardPerERC20TokenStored;
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @param initialAdmin The address of the initial contract admin.
    /// @param rewardERC20Token_ the address of the ERC20 token used for rewards
    /// @param sablierLockup_ the address of the ERC721 Contract
    constructor(address initialAdmin, IERC20 rewardERC20Token_, ISablierV2Lockup sablierLockup_) {
        admin = initialAdmin;
        rewardERC20Token = rewardERC20Token_;
        sablierLockup = sablierLockup_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Calculate the earned rewards for an account.
    /// @param account the address of the account to calculate available rewards for.
    /// @return earned the amount available as rewards for the account.
    function calculateRewards(address account) public view returns (uint256 earned) {
        if (stakedTokenId[account] == 0) {
            return rewards[account];
        } else {
            return (
                (
                    _getAmountInStream(stakedTokenId[account])
                        * (rewardPerERC20Token() - userRewardPerERC20TokenPaid[account])
                ) / 1e18
            ) + rewards[account];
        }
    }

    /// @notice getter function to get the reward per second for each ERC20 tokens staked via Sablier NFT.
    function getRewardPerToken() external view returns (uint256 _rewardPerERC20Token) {
        return rewardRate / totalERC20StakedSupply;
    }

    /// @return lastRewardsApplicable the last time the rewards were applicable. Returns Returns `block.timestamp` if
    /// the rewards period is not ended.
    function lastTimeRewardApplicable() public view returns (uint256 lastRewardsApplicable) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /// @notice calculates the rewards per ERC20 token for the current time whenever a new stake/unstake is made to keep
    /// track of the correct token distribution between stakers.
    function rewardPerERC20Token() public view returns (uint256) {
        if (totalERC20StakedSupply == 0) {
            return rewardPerERC20TokenStored;
        }
        return rewardPerERC20TokenStored
            + (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalERC20StakedSupply);
    }

    /// @notice function useful for Front End to see the staked NFT and earned rewards.
    /// @param account the address of the account to get informations for.
    /// @return stakedTokenId_ The Sablier NFT Token ID that is staked by the user.
    /// @return availableRewards_ the rewards accumulated by the user.
    function userStakeInfo(address account) public view returns (uint256 stakedTokenId_, uint256 availableRewards_) {
        return (stakedTokenId[account], calculateRewards(account));
    }

    /*//////////////////////////////////////////////////////////////////////////
                         USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function called by the user to claim his accumulated rewards
    function claimRewards() public updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            delete rewards[msg.sender];

            rewardERC20Token.safeTransfer(msg.sender, reward);

            emit RewardPaid(msg.sender, reward);
        }
    }

    /// @notice Implements the hook to handle the withdrawn amount if sender calls the withdraw.
    /// @dev This function transfers `amount` to the original staker.
    function onStreamWithdrawn(uint256 streamId, address, address, uint128 amount) external {
        // Check: the caller is the lockup contract
        if (msg.sender != address(sablierLockup)) {
            revert UnauthorizedCaller(msg.sender, streamId);
        }

        address staker = stakedAssets[streamId];

        // Check: the staker is not the zero address
        if (staker == address(0)) {
            revert ZeroAddress(streamId);
        }

        // Interaction: transfer the withdrawn amount to the original staker
        rewardERC20Token.safeTransfer(staker, amount);
    }

    /// @notice Stake a Sablier NFT with specified base asset
    /// @dev The `msg.sender` must approve the staking contract to spend the Sablier NFT before calling this function
    ///   One user can only stake one NFT at a time.
    /// @param tokenId The tokenId of the Sablier NFT to be staked
    function stake(uint256 tokenId) external updateReward(msg.sender) {
        // Check: the Sablier NFT is streaming the staking asset
        if (sablierLockup.getAsset(tokenId) != rewardERC20Token) {
            revert DifferentStreamingAsset(tokenId, rewardERC20Token);
        }

        // Check: the user is not already staking
        if (stakedAssets[tokenId] != address(0) || stakedTokenId[msg.sender] != 0) {
            revert ActiveStaker(msg.sender, stakedTokenId[msg.sender]);
        }

        // Effect: store the owner of the Sablier NFT
        stakedAssets[tokenId] = msg.sender;

        // Effect: Store the new tokenId against the user address
        stakedTokenId[msg.sender] = tokenId;

        // Effect: update the total staked amount
        totalERC20StakedSupply += _getAmountInStream(tokenId);

        // Interaction: transfer NFT to the staking contract
        sablierLockup.safeTransferFrom({ from: msg.sender, to: address(this), tokenId: tokenId });

        emit Staked(msg.sender, tokenId);
    }

    /// @notice Unstaking a Sablier NFT will transfer the NFT back to the `msg.sender`.
    /// @param tokenId The tokenId of the Sablier NFT to be unstaked.
    function unstake(uint256 tokenId) public updateReward(msg.sender) {
        // Check: the caller is the stored owner of the NFT
        if (stakedAssets[tokenId] != msg.sender) {
            revert UnauthorizedCaller(msg.sender, tokenId);
        }

        // Effect: delete the owner of the staked token from the storage
        delete stakedAssets[tokenId];

        // Effect: delete the `tokenId` from the user storage
        delete stakedTokenId[msg.sender];

        // Effect: update the total staked amount
        totalERC20StakedSupply -= _getAmountInStream(tokenId);

        // Interaction: transfer stream back to user
        sablierLockup.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Unstaked(msg.sender, tokenId);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Start a Staking period and set the amount of ERC20 Tokens to be distributed as rewards in said period
    /// @dev the Staking Contract have to already own enough Rewards Tokens to distribute all the rewards, so make sure
    /// to send all the tokens to the contract before calling this function
    /// @param rewardAmount the amount of Reward Tokens to be distributed
    /// @param newDuration the duration in with the rewards will be distributed
    function startStakingPeriod(uint256 rewardAmount, uint256 newDuration) external onlyAdmin {
        // Check: the amount is not zero
        if (rewardAmount == 0) {
            revert ZeroAmount();
        }

        // Check: the duration is not zero
        if (newDuration == 0) {
            revert ZeroDuration();
        }

        // Check: the staking period is not already active
        if (block.timestamp <= periodFinish) {
            revert StakingAlreadyActive();
        }

        // Effect: update the rewards duration
        rewardsDuration = newDuration;

        // Effect: update the reward rate
        rewardRate = rewardAmount / rewardsDuration;

        // Check: the contract has enough tokens to distribute as rewards
        uint256 balance = rewardERC20Token.balanceOf(address(this));
        if (rewardRate > balance / rewardsDuration) {
            revert ProvidedRewardTooHigh();
        }

        // Effect: update the `lastUpdateTime`
        lastUpdateTime = block.timestamp;

        // Effect: update the `periodFinish`
        periodFinish = block.timestamp + rewardsDuration;

        emit RewardAdded(rewardAmount);

        emit RewardDurationUpdated(rewardsDuration);
    }

    /*//////////////////////////////////////////////////////////////////////////
                         INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to get the amount of tokens in the stream.
    /// @dev The following function only applied to non-cancelable streams.
    function _getAmountInStream(uint256 tokenId) internal view returns (uint256 amount) {
        return sablierLockup.getDepositedAmount(tokenId) - sablierLockup.getWithdrawnAmount(tokenId);
    }
}
