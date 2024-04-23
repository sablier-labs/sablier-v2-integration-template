// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Adminable } from "@sablier/v2-core/src/abstracts/Adminable.sol";
import { ISablierV2Lockup } from "@sablier/v2-core/src/interfaces/ISablierV2Lockup.sol";

/// @title StakeSablierNFT
/// @notice DISCLAIMER: This template has not been audited and is provided "as is" with no warranties of any kind,
/// either express or implied. It is intended solely for demonstration purposes on how to build a staking contract
/// using Sablier NFT. This template should not be used in a production environment. It makes specific assumptions that
/// may not be applicable to your particular needs.
/// @dev This template allows users to stake Sablier NFTs and earn staking rewards.
///
///   Requirements:
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

    error ClaimAmountExceedsBalance(uint256 claimAmount, uint256 balance);
    error InvalidToken(IERC20 streamingToken, IERC20 rewardToken);
    error NotStaked(uint256 tokenId);
    error NotAuthorized(address account, uint256 tokenId);
    error ZeroAmount();

    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the claimable rewards are updated.
    event ClaimAmountUpdated(uint256 tokenId);

    /// @notice Emitted when a Sablier NFT is staked.
    event Staked(address indexed account, uint256 indexed tokenId);

    /// @notice Emitted when a Sablier NFT is unstaked.
    event Unstaked(address indexed account, uint256 indexed tokenId);

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

    /// @dev Available staking rewards to claim mapped by tokenId.
    mapping(uint256 tokenId => uint256 amount) public stakingRewards;

    /// @dev The last timestamp when rewards were updated mapped by tokenId.
    mapping(uint256 tokenId => uint256 timestamp) public lastUpdateTimestamp;

    /// @dev The owner of the Sablier stream mapped by tokenId.
    mapping(uint256 tokenId => address owner) public streamOwner;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Check:
    //   - if NFT is staked, `msg.sender` must be the stored owner of the Sablier Stream
    //   - if NFT is not staked, `msg.sender` must be the recipient of the Sablier NFT
    modifier isCallerAuthorized(uint256 tokenId) {
        if (msg.sender != streamOwner[tokenId] && msg.sender != SABLIER_CONTRACT.getRecipient(tokenId)) {
            revert NotAuthorized(msg.sender, tokenId);
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
                            USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Check if the `tokenId` is staked.
    /// @param tokenId The tokenId of the Sablier NFT.
    function isStaked(uint256 tokenId) public view returns (bool) {
        return streamOwner[tokenId] != address(0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                         USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Claim the staking rewards for the `tokenId`.
    /// @dev
    ///   - If NFT is staked, the staking rewards are updated before claiming
    ///   - If NFT is not staked, the staking rewards are loaded from storage
    /// @param tokenId The tokenId of the Sablier NFT to withdraw rewards for
    function claim(uint256 tokenId) public isCallerAuthorized(tokenId) {
        // Effect: update and return the claimable rewards
        uint256 claimAmount = updateClaimAmount(tokenId);

        // Interaction: claim the rewards
        _claim(claimAmount, tokenId);
    }

    /// @notice Stake a Sablier NFT with specified base asset
    /// @dev The `msg.sender` must approve the staking contract to spend the Sablier NFT before calling this function
    /// @param tokenId The tokenId of the Sablier NFT to be staked
    function stake(uint256 tokenId) public isCallerAuthorized(tokenId) {
        // Check: if the Sablier NFT was minted with the staking asset
        IERC20 streamingAsset = IERC20(SABLIER_CONTRACT.getAsset(tokenId));
        if (streamingAsset != REWARD_TOKEN) {
            revert InvalidToken(streamingAsset, REWARD_TOKEN);
        }

        // Effect: store the owner of the Sablier NFT
        streamOwner[tokenId] = msg.sender;

        // Effect: set the block timestamp as the last update timestamp for rewards calculation
        lastUpdateTimestamp[tokenId] = block.timestamp;

        // Interaction: transfer NFT to the staking contract
        SABLIER_CONTRACT.transferFrom({ from: msg.sender, to: address(this), tokenId: tokenId });

        emit Staked(msg.sender, tokenId);
    }

    /// @notice Unstaking a Sablier NFT will transfer the NFT back to the `msg.sender`.
    /// @param tokenId The tokenId of the Sablier NFT to be unstaked
    function unstake(uint256 tokenId) public isCallerAuthorized(tokenId) {
        // Check: if the `tokenId` is staked
        if (!isStaked(tokenId)) {
            revert NotStaked(tokenId);
        }

        // Effect: update the claimable rewards
        updateClaimAmount(tokenId);

        // Effect: delete the owner of the Sablier Stream from the storage
        delete streamOwner[tokenId];

        // Interaction: transfer stream back to user
        SABLIER_CONTRACT.transferFrom(address(this), msg.sender, tokenId);

        emit Unstaked(msg.sender, tokenId);
    }

    /// @notice Update the claimable rewards for the `tokenId`
    /// @dev If token Id is not staked, this function returns `stakingRewards` from storage
    /// @param tokenId The tokenId of the staked Sablier NFT
    /// @return claimAmount The staking rewards available to claim for the `tokenId`
    function updateClaimAmount(uint256 tokenId) public returns (uint256 claimAmount) {
        // Load the staking rewards from storage
        uint256 _stakingRewards = stakingRewards[tokenId];

        // Return the stored staking rewards if the NFT is not staked
        if (SABLIER_CONTRACT.getRecipient(tokenId) != address(this)) {
            return _stakingRewards;
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
        _stakingRewards += (REWARD_RATE * tokensInStream * rewardPeriod) / 1e18;
        stakingRewards[tokenId] = _stakingRewards;

        // Effect: update the reward timestamp
        lastUpdateTimestamp[tokenId] = block.timestamp;

        emit ClaimAmountUpdated(tokenId);

        return _stakingRewards;
    }

    /*//////////////////////////////////////////////////////////////////////////
                         INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Internal function to claim the staking rewards for the `tokenId`
    function _claim(uint256 claimAmount, uint256 tokenId) internal {
        if (claimAmount == 0) {
            revert ZeroAmount();
        }

        // Fetch the staking contract balance
        uint256 stakingContractBalance = REWARD_TOKEN.balanceOf(address(this));

        // Check: if the claim amount does not exceed the staking contract balance
        if (claimAmount > stakingContractBalance) {
            revert ClaimAmountExceedsBalance(claimAmount, stakingContractBalance);
        }

        // Effect: set the claimable rewards to zero
        stakingRewards[tokenId] = 0;

        // Interaction: transfer rewards to the original stream owner
        REWARD_TOKEN.transfer(msg.sender, claimAmount);
    }
}
