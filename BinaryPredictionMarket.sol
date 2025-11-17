// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BinaryPredictionMarket is ReentrancyGuard, Ownable {
    enum MarketState { Open, Resolved, Cancelled }

    struct Market {
        string question;
        uint64 deadline;
        MarketState state;
        uint128 totalStakeYes;
        uint128 totalStakeNo;
        uint8 outcome;
    }

    error InvalidSide();
    error ZeroStake();
    error MarketNotOpen();
    error BettingClosed();
    error InvalidOutcome();
    error NotEnded();
    error AlreadySettled();
    error NoWinningStake();
    error RefundFailed();
    error PayoutFailed();

    uint256 public nextMarketId;

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => mapping(uint8 => uint256))) public bets;

    event MarketCreated(uint256 marketId, string question, uint256 deadline);
    event BetPlaced(uint256 marketId, address user, uint8 side, uint256 amount);
    event MarketResolved(uint256 marketId, uint8 outcome);
    event MarketCancelled(uint256 marketId);
    event Claimed(uint256 marketId, address user, uint256 amount);

    function createMarket(
        string calldata question,
        uint256 bettingDurationSeconds
    )
        external
        onlyOwner
        returns (uint256 marketId)
    {
        if (bettingDurationSeconds == 0) revert ZeroStake();

        marketId = nextMarketId;
        unchecked {
            nextMarketId = marketId + 1;
        }

        uint64 end = uint64(block.timestamp + bettingDurationSeconds);

        markets[marketId] = Market({
            question: question,
            deadline: end,
            state: MarketState.Open,
            totalStakeYes: 0,
            totalStakeNo: 0,
            outcome: 0
        });

        emit MarketCreated(marketId, question, end);
    }

    function placeBet(uint256 marketId, uint8 side) external payable {
        if (side > 1) revert InvalidSide();
        if (msg.value == 0) revert ZeroStake();

        Market storage m = markets[marketId];

        if (m.state != MarketState.Open) revert MarketNotOpen();
        if (block.timestamp > m.deadline) revert BettingClosed();

        uint256 amount = msg.value;
        bets[marketId][msg.sender][side] += amount;

        if (side == 1) {
            m.totalStakeYes += uint128(amount);
        } else {
            m.totalStakeNo += uint128(amount);
        }

        emit BetPlaced(marketId, msg.sender, side, amount);
    }

    function resolveMarket(uint256 marketId, uint8 outcome) external onlyOwner {
        if (outcome > 1) revert InvalidOutcome();

        Market storage m = markets[marketId];

        if (m.state != MarketState.Open) revert MarketNotOpen();
        if (block.timestamp <= m.deadline) revert NotEnded();

        m.state = MarketState.Resolved;
        m.outcome = outcome;

        emit MarketResolved(marketId, outcome);
    }

    function cancelMarket(uint256 marketId) external onlyOwner {
        Market storage m = markets[marketId];

        if (m.state != MarketState.Open) revert AlreadySettled();

        m.state = MarketState.Cancelled;

        emit MarketCancelled(marketId);
    }

    function claim(uint256 marketId) external nonReentrant {
        Market storage m = markets[marketId];
        MarketState state = m.state;

        if (state != MarketState.Resolved && state != MarketState.Cancelled) {
            revert AlreadySettled();
        }

        address user = msg.sender;

        if (state == MarketState.Cancelled) {
            uint256 s0 = bets[marketId][user][0];
            uint256 s1 = bets[marketId][user][1];
            uint256 refund = s0 + s1;

            if (refund == 0) revert NoWinningStake();

            bets[marketId][user][0] = 0;
            bets[marketId][user][1] = 0;

            (bool ok, ) = user.call{value: refund}("");
            if (!ok) revert RefundFailed();

            emit Claimed(marketId, user, refund);
            return;
        }

        uint8 winningSide = m.outcome;
        uint256 stake = bets[marketId][user][winningSide];

        if (stake == 0) revert NoWinningStake();

        bets[marketId][user][winningSide] = 0;

        uint256 totalWinningPool = (winningSide == 1)
            ? m.totalStakeYes
            : m.totalStakeNo;

        uint256 totalLosingPool = (winningSide == 1)
            ? m.totalStakeNo
            : m.totalStakeYes;

        uint256 bonus = 0;
        if (totalLosingPool > 0) {
            bonus = (stake * totalLosingPool) / totalWinningPool;
        }

        uint256 payout = stake + bonus;

        (bool sent, ) = user.call{value: payout}("");
        if (!sent) revert PayoutFailed();

        emit Claimed(marketId, user, payout);
    }

    function getUserStake(
        uint256 marketId,
        address user,
        uint8 side
    )
        external
        view
        returns (uint256)
    {
        return bets[marketId][user][side];
    }

    receive() external payable {
        revert("invalid");
    }
}
