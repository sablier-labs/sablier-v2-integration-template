// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Adminable } from "@sablier/v2-core/src/abstracts/Adminable.sol";
import { ISablierV2Lockup } from "@sablier/v2-core/src/interfaces/ISablierV2Lockup.sol";

/// @title StakeSablierNFT
/// @dev This contract allows users to stake Sablier NFTs and earn staking rewards.
///
///   Requirements:
///     - The Sablier NFT must be minted by creating a stream of the reward token.
///     - The Sablier NFT must be transferrable.
///
///  Risks:
///     - The sender MUST NOT call `withdraw()` for staked NFTs. If the sender calls `withdraw()` for staked NFTs, the
/// funds will be sent to the staking contract and will be locked forever.
///     - The sender MUST NOT cancel the stream for staked NFTs. If the sender cancels the stream for staked NFTs, the
/// rewards calculation will not account for unvested tokens.
contract StakeSablierNFT is Adminable {
    /*//////////////////////////////////////////////////////////////////////////
                                       ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error NotAuthorized(uint256);
    error NotStaked(uint256);
    error NotStreamOwner(address, uint256);

    /*//////////////////////////////////////////////////////////////////////////
                                USER-FACING STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Rewards rate per 1e18 tokens.
    uint256 public immutable REWARD_RATE;

    /// @dev This should be your own ERC20 token in which the staking rewards will be distributed.
    IERC20 public immutable REWARD_TOKEN;

    /// @dev This should be the Sablier Lockup contract.
    //    - If you used Lockup Linear, you should use the LockupLinear contract address.
    //    - If you used Lockup Dynamic, you should use the LockupDynamic contract address.
    ISablierV2Lockup public immutable SABLIER_CONTRACT;

    /// @dev The amount available to claim mapped by tokenId.
    mapping(uint256 tokenId => uint256 amount) public claimAmount;

    /// @dev The last timestamp when rewards were updated mapped by tokenId.
    mapping(uint256 tokenId => uint256 timestamp) public lastUpdateTimestamp;

    /// @dev The owner of the Sablier stream mapped by tokenId.
    mapping(uint256 tokenId => address owner) public streamOwner;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier onlyStreamOwner(uint256 tokenId) {
        // Check: if the `msg.sender` is the stored owner of the Sablier Stream
        if (streamOwner[tokenId] != msg.sender) {
            revert NotStreamOwner(msg.sender, tokenId);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @param initialAdmin The address of the initial contract admin.
    /// @param rewardToken The token for distributing staking rewards.
    /// @param sablierLockup Sablier Lockup contract used for streaming.
    constructor(address initialAdmin, uint256 rewardRate, IERC20 rewardToken, ISablierV2Lockup sablierLockup) {
        admin = initialAdmin;
        REWARD_RATE = rewardRate;
        REWARD_TOKEN = rewardToken;
        SABLIER_CONTRACT = sablierLockup;
    }

    /*//////////////////////////////////////////////////////////////////////////
                         USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Stake a Sablier NFT with specified base asset
    /// @dev The `msg.sender` must approve the staking contract to spend the Sablier NFT before calling this function
    /// @param tokenId The tokenId of the Sablier NFT to be staked
    function stake(uint256 tokenId) public {
        // Check: if the Sablier NFT was minted with the staking asset
        if (SABLIER_CONTRACT.getAsset(tokenId) != REWARD_TOKEN) {
            revert NotAuthorized(tokenId);
        }

        // Check: if the Sablier NFT is owned by the `msg.sender`
        if (SABLIER_CONTRACT.getRecipient(tokenId) != msg.sender) {
            revert NotStreamOwner(msg.sender, tokenId);
        }

        // Effect: store the owner of the Sablier NFT
        streamOwner[tokenId] = msg.sender;

        // Effect: set the block timestamp as the last update timestamp for rewards calculation
        lastUpdateTimestamp[tokenId] = block.timestamp;

        // Interaction: transfer NFT to the staking contract
        SABLIER_CONTRACT.transferFrom({ from: msg.sender, to: address(this), tokenId: tokenId });
    }

    /// @notice Unstaking a Sablier NFT will transfer the NFT back to the `msg.sender`. The rewards will also be
    /// transferred to the `msg.sender`
    /// @dev This function can only be called by the original owner of the Sablier NFT
    /// @param tokenId The tokenId of the Sablier NFT to be unstaked
    function unstake(uint256 tokenId) public onlyStreamOwner(tokenId) {
        // Check: if the Sablier NFT is staked
        if (SABLIER_CONTRACT.getRecipient(tokenId) != address(this)) {
            revert NotStaked(tokenId);
        }

        // Effect: update the claimable rewards
        uint256 stakingRewards = updateClaimAmount(tokenId);

        // Effect: set the claimable rewards to zero
        claimAmount[tokenId] = 0;

        // Effect: delete the owner of the Sablier Stream from the storage
        delete streamOwner[tokenId];

        // Interaction: transfer stream back to user
        SABLIER_CONTRACT.transferFrom(address(this), msg.sender, tokenId);

        // Interaction: transfer rewards to `msg.sender`
        REWARD_TOKEN.transfer(msg.sender, stakingRewards);
    }

    /// @notice Update the claimable rewards for the `tokenId`
    /// @dev If token Id is not staked, this function returns `claimAmount`
    /// @param tokenId The tokenId of the staked Sablier NFT
    /// @return stakingRewards The staking rewards available to claim for the `tokenId`
    function updateClaimAmount(uint256 tokenId) public returns (uint256 stakingRewards) {
        // Do nothing if the Sablier NFT is not staked
        if (SABLIER_CONTRACT.getRecipient(tokenId) != address(this)) {
            return claimAmount[tokenId];
        }

        // Calculate the reward period since the last update
        uint256 rewardPeriod = block.timestamp - lastUpdateTimestamp[tokenId];

        // Calculate rewards for each stream
        uint256 tokensInStream;

        if (SABLIER_CONTRACT.isCancelable(tokenId)) {
            // If the stream is cancelable, the tokens in the stream are the sum of amount available to withdraw and
            // the amount that can be refunded to the sender
            tokensInStream =
                SABLIER_CONTRACT.withdrawableAmountOf(tokenId) + SABLIER_CONTRACT.refundableAmountOf(tokenId);
        } else {
            // If the stream is not cancelable, the tokens in the stream are the difference between the amount
            // deposited and the amount withdrawn
            tokensInStream = SABLIER_CONTRACT.getDepositedAmount(tokenId) - SABLIER_CONTRACT.getWithdrawnAmount(tokenId);
        }

        // Effect: update the claim amount
        claimAmount[tokenId] += (REWARD_RATE * tokensInStream * rewardPeriod) / 1e18;

        // Effect: update the reward timestamp
        lastUpdateTimestamp[tokenId] = block.timestamp;

        return claimAmount[tokenId];
    }

    /// @notice Withdraw the claimable rewards for the `tokenId`
    /// @dev This function can only be called by the original owner of the Sablier NFT
    /// @param tokenId The tokenId of the Sablier NFT to withdraw rewards for
    function withdrawRewards(uint256 tokenId) public onlyStreamOwner(tokenId) {
        // Effect: update the claimable rewards
        uint256 stakingRewards = updateClaimAmount(tokenId);

        // Effect: set the claimable rewards to zero
        claimAmount[tokenId] = 0;

        // Interaction: transfer rewards to the original stream owner
        REWARD_TOKEN.transfer(msg.sender, stakingRewards);
    }
}
