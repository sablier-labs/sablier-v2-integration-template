// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud2x18 } from "@prb/math/src/UD2x18.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierV2LockupDynamic } from "@sablier/v2-core/src/interfaces/ISablierV2LockupDynamic.sol";
import { Broker, LockupDynamic } from "@sablier/v2-core/src/types/DataTypes.sol";

/// @dev Already deployed on testnet at this address:
/// https://sepolia.etherscan.io/address/0xa881C85039daa92330B72A00c5932750A8f11F11#code
contract CliffExponetialCreator {
    /// Contracts deployed on Sepolia testnet: https://docs.sablier.com/contracts/v2/deployments#sepolia
    IERC20 public constant DAI = IERC20(0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357);
    ISablierV2LockupDynamic public constant LOCKUP_DYNAMIC =
        ISablierV2LockupDynamic(0xc9940AD8F43aAD8e8f33A4D5dbBf0a8F7FF4429A);

    uint256[] internal streamIdsCreated;

    function getStreamIdsCreated() external view returns (uint256[] memory) {
        return streamIdsCreated;
    }

    function createStream() external returns (uint256 streamId) {
        // Declare the total amount as 100 DAI
        uint128 totalAmount = 100e18;

        // Transfer the provided amount of DAI tokens to this contract
        DAI.transferFrom(msg.sender, address(this), totalAmount);

        // Approve the Sablier contract to spend DAI
        DAI.approve(address(LOCKUP_DYNAMIC), totalAmount);

        // Declare the params struct
        LockupDynamic.CreateWithDeltas memory params;

        // Declare the function parameters
        params.sender = msg.sender; // The sender will be able to cancel the stream
        params.recipient = msg.sender; // The recipient of the streamed assets
        params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
        params.asset = DAI; // The streaming asset
        params.cancelable = true; // Whether the stream will be cancelable or not
        params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

        // Declare a three-size segment to match the curve shape
        params.segments = new LockupDynamic.SegmentWithDelta[](3);
        params.segments[0] =
            LockupDynamic.SegmentWithDelta({ amount: 0, delta: 50 days - 1 seconds, exponent: ud2x18(1e18) });
        params.segments[1] = LockupDynamic.SegmentWithDelta({ amount: 20e18, delta: 1 seconds, exponent: ud2x18(3e18) });
        params.segments[2] = LockupDynamic.SegmentWithDelta({ amount: 80e18, delta: 50 days, exponent: ud2x18(3e18) });

        // Create the LockupDynamic stream
        streamId = LOCKUP_DYNAMIC.createWithDeltas(params);

        streamIdsCreated.push(streamId);
    }
}
