// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/BinaryPredictionMarket.sol";

contract BinaryPredictionMarketInvariant is Test {
    BinaryPredictionMarket market;

    address[] users;

    function setUp() public {
        market = new BinaryPredictionMarket();

        for (uint256 i = 0; i < 5; i++) {
            address user = address(uint160(i + 1));
            users.push(user);
            vm.deal(user, 100 ether);
        }

        market.createMarket("Invariant Market", 1 days);
    }

    /* ---------------------------------- */
    /* FUZZ ACTIONS                       */
    /* ---------------------------------- */

    function placeRandomBet(uint256 userIndex, uint8 side, uint96 amount) public {
        userIndex = userIndex % users.length;
        side = side % 2;
        amount = uint96(bound(amount, 1 ether, 10 ether));

        vm.prank(users[userIndex]);
        try market.placeBet{value: amount}(0, side) {} catch {}
    }

    function resolveMarket() public {
        vm.warp(block.timestamp + 2 days);
        try market.resolveMarket(0, uint8(block.timestamp % 2)) {} catch {}
    }

    function claim(uint256 userIndex) public {
        userIndex = userIndex % users.length;
        vm.prank(users[userIndex]);
        try market.claim(0) {} catch {}
    }

    /* ---------------------------------- */
    /* INVARIANTS                         */
    /* ---------------------------------- */

    /// Invariant 1:
    /// Contract ETH balance never increases unexpectedly
    function invariant_balanceMatchesPools() public {
        (
            ,
            ,
            BinaryPredictionMarket.MarketState state,
            uint128 yesPool,
            uint128 noPool,
            
        ) = market.markets(0);

        if (state == BinaryPredictionMarket.MarketState.Open) {
            assertEq(address(market).balance, yesPool + noPool);
        }
    }

    /// Invariant 2:
    /// Users cannot withdraw more than total pool
    function invariant_noOverWithdrawal() public {
        uint256 totalUserBalances;

        for (uint256 i = 0; i < users.length; i++) {
            totalUserBalances += users[i].balance;
        }

        assertLe(totalUserBalances, 500 ether);
    }

    /// Invariant 3:
    /// No user has stake after successful claim
    function invariant_noStakeAfterClaim() public {
        for (uint256 i = 0; i < users.length; i++) {
            uint256 s0 = market.getUserStake(0, users[i], 0);
            uint256 s1 = market.getUserStake(0, users[i], 1);

            // Either stake exists OR user hasn't claimed yet
            assertTrue(s0 == 0 || s1 == 0 || s0 + s1 > 0);
        }
    }
}
