// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/BinaryPredictionMarket.sol";

contract BinaryPredictionMarketTest is Test {
    BinaryPredictionMarket market;

    address owner = address(this);
    address alice = address(0xA1);
    address bob   = address(0xB2);

    function setUp() public {
        market = new BinaryPredictionMarket();
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function _createMarket() internal returns (uint256) {
        return market.createMarket("Will ETH hit 5k?", 1 days);
    }

    function testCreateMarket() public {
        uint256 id = _createMarket();
        (
            ,
            uint64 deadline,
            BinaryPredictionMarket.MarketState state,
            ,
            ,
            
        ) = market.markets(id);

        assertEq(uint8(state), uint8(BinaryPredictionMarket.MarketState.Open));
        assertGt(deadline, block.timestamp);
    }

    function testPlaceBetYes() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        market.placeBet{value: 2 ether}(id, 1);

        assertEq(market.getUserStake(id, alice, 1), 2 ether);
    }

    function testCannotBetAfterDeadline() public {
        uint256 id = _createMarket();
        vm.warp(block.timestamp + 2 days);

        vm.prank(alice);
        vm.expectRevert(BinaryPredictionMarket.BettingClosed.selector);
        market.placeBet{value: 1 ether}(id, 0);
    }

    function testResolveAndClaimWinner() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        market.placeBet{value: 2 ether}(id, 1);

        vm.prank(bob);
        market.placeBet{value: 2 ether}(id, 0);

        vm.warp(block.timestamp + 2 days);
        market.resolveMarket(id, 1);

        uint256 balBefore = alice.balance;

        vm.prank(alice);
        market.claim(id);

        assertEq(alice.balance - balBefore, 4 ether);
    }

    function testLoserCannotClaim() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        market.placeBet{value: 1 ether}(id, 1);

        vm.warp(block.timestamp + 2 days);
        market.resolveMarket(id, 1);

        vm.prank(bob);
        vm.expectRevert(BinaryPredictionMarket.NoWinningStake.selector);
        market.claim(id);
    }

    function testCancelRefundsUser() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        market.placeBet{value: 3 ether}(id, 0);

        market.cancelMarket(id);

        uint256 balBefore = alice.balance;

        vm.prank(alice);
        market.claim(id);

        assertEq(alice.balance - balBefore, 3 ether);
    }

    function testCannotClaimTwice() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        market.placeBet{value: 1 ether}(id, 1);

        vm.warp(block.timestamp + 2 days);
        market.resolveMarket(id, 1);

        vm.prank(alice);
        market.claim(id);

        vm.prank(alice);
        vm.expectRevert(BinaryPredictionMarket.NoWinningStake.selector);
        market.claim(id);
    }
}
