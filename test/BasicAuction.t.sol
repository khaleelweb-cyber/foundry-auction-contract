// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {BasicAuction} from "../src/BasicAuction.sol";

contract BasicAuctionTest is Test {
    BasicAuction public auction;

    address public owner = 0x42b898c3f62dfDD929f15a8014D4085044e634d7;
    address public bidderA = 0x0de08F535321c3c543Ae5D447Ad70aD7293760dF;
    address public bidderB = 0xE52529e0cCB1D17855aa5ed4401BC63e5142cdE3;
    address public bidderC = 0xc9dfD2CBB10C78466d82851f336D3B07F2dD83cA;

    // Must match the hardcoded address in the contract
    address public beneficiary = 0x42b898c3f62dfDD929f15a8014D4085044e634d7;

    uint256 public constant DURATION = 1 hours;

    function setUp() public {
        vm.deal(bidderA, 10 ether);
        vm.deal(bidderB, 10 ether);
        vm.deal(bidderC, 10 ether);

        vm.prank(owner);
        auction = new BasicAuction();
    }

    ////////////////////////////////////////////////////////////////
    // Deployment
    ////////////////////////////////////////////////////////////////

    function testOwnerSetCorrectly() public view {
        assertEq(auction.owner(), owner);
    }

    function testBeneficiarySetCorrectly() public view {
        assertEq(auction.beneficiary(), beneficiary);
    }

    function testAuctionEndTimeSetCorrectly() public view {
        assertEq(auction.auctionEndTime(), block.timestamp + DURATION);
    }

    function testAuctionNotEndedOnDeploy() public view {
        assertFalse(auction.ended());
    }

    function testHighestBidIsZeroOnDeploy() public view {
        assertEq(auction.highestBid(), 0);
    }

    function testHighestBidderIsZeroAddressOnDeploy() public view {
        assertEq(auction.highestBidder(), address(0));
    }

    function testTimeRemainingIsOnHourOnDeploy() public view {
        assertEq(auction.timeRemaining(), DURATION);
    }

    ////////////////////////////////////////////////////////////////
    // bid()
    ////////////////////////////////////////////////////////////////

    function testFirstBidSucceeds() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        assertEq(auction.highestBid(), 1 ether);
        assertEq(auction.highestBidder(), bidderA);
    }

    function testHigherBidReplacesCurrentHighest() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        auction.bid{value: 2 ether}();

        assertEq(auction.highestBid(), 2 ether);
        assertEq(auction.highestBidder(), bidderB);
    }

    function testOutbidBidderAddedToPendingReturns() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        auction.bid{value: 2 ether}();

        assertEq(auction.pendingReturns(bidderA), 1 ether);
    }

    function testBidRevertsIfLowerThanCurrentHighest() public {
        vm.prank(bidderA);
        auction.bid{value: 2 ether}();

        vm.prank(bidderB);
        vm.expectRevert(
            abi.encodeWithSelector(
                BasicAuction.BidNotHighEnough.selector,
                2 ether
            )
        );
        auction.bid{value: 1 ether}();
    }

    function testBidRevertsIfEqualToCurrentHighest() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        vm.expectRevert(
            abi.encodeWithSelector(
                BasicAuction.BidNotHighEnough.selector,
                1 ether
            )
        );
        auction.bid{value: 1 ether}();
    }

    function testBidRevertsAfterAuctionExpires() public {
        vm.warp(block.timestamp + DURATION + 1);

        vm.prank(bidderA);
        vm.expectRevert(BasicAuction.AuctionAlreadyEnded.selector);
        auction.bid{value: 1 ether}();
    }

    function testBidRevertsWithZeroValue() public {
        vm.prank(bidderA);
        vm.expectRevert(
            abi.encodeWithSelector(BasicAuction.BidNotHighEnough.selector, 0)
        );
        auction.bid{value: 0}();
    }

    function testThreeBiddersAccumulatePendingReturnsCorrectly() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        auction.bid{value: 2 ether}();

        vm.prank(bidderA);
        auction.bid{value: 3 ether}();

        // bidderA was outbid first (1 ether pending), then outbid bidderB
        assertEq(auction.pendingReturns(bidderA), 1 ether);
        // bidderB was outbid by bidderA's second bid (2 ether pending)
        assertEq(auction.pendingReturns(bidderB), 2 ether);
        // bidderA is current winner — no pending for them
        assertEq(auction.highestBidder(), bidderA);
        assertEq(auction.highestBid(), 3 ether);
    }

    function testFirstBidDoesNotCreatePendingForZeroAddress() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        assertEq(auction.pendingReturns(address(0)), 0);
    }

    function testNewHighestBidEventEmitted() public {
        vm.prank(bidderA);
        vm.expectEmit(true, false, false, true);
        emit BasicAuction.NewHighestBid(bidderA, 1 ether);
        auction.bid{value: 1 ether}();
    }

    function testContractReceivesETHOnBid() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        assertEq(address(auction).balance, 1 ether);
    }

    function testContractBalanceGrowsWithHigherBids() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        auction.bid{value: 3 ether}();

        // Both bids are held — 1 ether pending + 3 ether highest bid
        assertEq(address(auction).balance, 4 ether);
    }

    ////////////////////////////////////////////////////////////////
    // withdraw()
    ////////////////////////////////////////////////////////////////

    function testWithdrawReturnsETHToOutbidBidder() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        auction.bid{value: 2 ether}();

        uint256 balanceBefore = bidderA.balance;

        vm.prank(bidderA);
        auction.withdraw();

        assertEq(bidderA.balance, balanceBefore + 1 ether);
    }

    function testWithdrawClearsPendingReturns() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        auction.bid{value: 2 ether}();

        vm.prank(bidderA);
        auction.withdraw();

        assertEq(auction.pendingReturns(bidderA), 0);
    }

    function testWithdrawReturnsFalseIfNoPendingBalance() public {
        vm.prank(bidderA);
        bool result = auction.withdraw();

        assertFalse(result);
    }

    function testWithdrawReturnsTrueOnSuccess() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        auction.bid{value: 2 ether}();

        vm.prank(bidderA);
        bool result = auction.withdraw();

        assertTrue(result);
    }

    function testCannotWithdrawTwice() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        auction.bid{value: 2 ether}();

        vm.prank(bidderA);
        auction.withdraw();

        uint256 balanceAfterFirst = bidderA.balance;

        vm.prank(bidderA);
        auction.withdraw();

        assertEq(bidderA.balance, balanceAfterFirst);
    }

    function testWithdrawReducesContractBalance() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        auction.bid{value: 2 ether}();

        uint256 contractBalanceBefore = address(auction).balance;

        vm.prank(bidderA);
        auction.withdraw();

        assertEq(address(auction).balance, contractBalanceBefore - 1 ether);
    }

    function testWithdrawalEventEmitted() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        auction.bid{value: 2 ether}();

        vm.prank(bidderA);
        vm.expectEmit(true, false, false, true);
        emit BasicAuction.Withdrawal(bidderA, 1 ether);
        auction.withdraw();
    }

    function testWithdrawCanBeCalledAfterAuctionEnds() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        auction.bid{value: 2 ether}();

        vm.warp(block.timestamp + DURATION + 1);
        auction.endAuction();

        uint256 balanceBefore = bidderA.balance;

        vm.prank(bidderA);
        auction.withdraw();

        assertEq(bidderA.balance, balanceBefore + 1 ether);
    }

    ////////////////////////////////////////////////////////////////
    // endAuction()
    ////////////////////////////////////////////////////////////////

    function testEndAuctionSendsFundsToBeneficiary() public {
        vm.prank(bidderA);
        auction.bid{value: 3 ether}();

        uint256 balanceBefore = beneficiary.balance;

        vm.warp(block.timestamp + DURATION + 1);
        auction.endAuction();

        assertEq(beneficiary.balance, balanceBefore + 3 ether);
    }

    function testEndAuctionSetsEndedTrue() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.warp(block.timestamp + DURATION + 1);
        auction.endAuction();

        assertTrue(auction.ended());
    }

    function testEndAuctionRevertsBeforeEndTime() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.expectRevert(BasicAuction.AuctionNotYetEnded.selector);
        auction.endAuction();
    }

    function testEndAuctionRevertsIfCalledTwice() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.warp(block.timestamp + DURATION + 1);
        auction.endAuction();

        vm.expectRevert(BasicAuction.AuctionEndAlreadyCalled.selector);
        auction.endAuction();
    }

    function testEndAuctionAtExactEndTime() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        // Warp to exactly the end time (not +1)
        vm.warp(block.timestamp + DURATION);
        auction.endAuction();

        assertTrue(auction.ended());
    }

    function testEndAuctionWithNoBidsSendsZeroToBeneficiary() public {
        uint256 balanceBefore = beneficiary.balance;

        vm.warp(block.timestamp + DURATION + 1);
        auction.endAuction();

        assertEq(beneficiary.balance, balanceBefore);
        assertTrue(auction.ended());
    }

    function testAuctionEndedEventEmitted() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.warp(block.timestamp + DURATION + 1);
        vm.expectEmit(true, false, false, true);
        emit BasicAuction.AuctionEnded(bidderA, 1 ether);
        auction.endAuction();
    }

    function testBidRevertsAfterEndAuctionCalled() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.warp(block.timestamp + DURATION + 1);
        auction.endAuction();

        vm.prank(bidderB);
        vm.expectRevert(BasicAuction.AuctionAlreadyEnded.selector);
        auction.bid{value: 2 ether}();
    }

    ////////////////////////////////////////////////////////////////
    // timeRemaining()
    ////////////////////////////////////////////////////////////////

    function testTimeRemainingAtDeployIsOneHour() public view {
        assertEq(auction.timeRemaining(), DURATION);
    }

    function testTimeRemainingDecreasesOverTime() public {
        vm.warp(block.timestamp + 30 minutes);
        assertEq(auction.timeRemaining(), 30 minutes);
    }

    function testTimeRemainingReturnsZeroAtExactEndTime() public {
        vm.warp(block.timestamp + DURATION);
        assertEq(auction.timeRemaining(), 0);
    }

    function testTimeRemainingReturnsZeroAfterEndTime() public {
        vm.warp(block.timestamp + DURATION + 999);
        assertEq(auction.timeRemaining(), 0);
    }

    ////////////////////////////////////////////////////////////////
    // pendingReturnFor()
    ////////////////////////////////////////////////////////////////

    function testPendingReturnForReturnsCorrectAmount() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        auction.bid{value: 2 ether}();

        assertEq(auction.pendingReturnFor(bidderA), 1 ether);
    }

    function testPendingReturnForReturnsZeroForNonBidder() public view {
        assertEq(auction.pendingReturnFor(bidderC), 0);
    }

    function testPendingReturnForReturnsZeroAfterWithdrawal() public {
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();

        vm.prank(bidderB);
        auction.bid{value: 2 ether}();

        vm.prank(bidderA);
        auction.withdraw();

        assertEq(auction.pendingReturnFor(bidderA), 0);
    }

    ////////////////////////////////////////////////////////////////
    // Full auction lifecycle
    ////////////////////////////////////////////////////////////////

    function testFullAuctionLifecycle() public {
        // Three bidders compete
        vm.prank(bidderA);
        auction.bid{value: 1 ether}();
        assertEq(auction.highestBidder(), bidderA);
        assertEq(auction.highestBid(), 1 ether);

        vm.prank(bidderB);
        auction.bid{value: 2 ether}();
        assertEq(auction.highestBidder(), bidderB);
        assertEq(auction.pendingReturns(bidderA), 1 ether);

        vm.prank(bidderC);
        auction.bid{value: 3 ether}();
        assertEq(auction.highestBidder(), bidderC);
        assertEq(auction.pendingReturns(bidderB), 2 ether);

        // bidderA withdraws mid-auction
        uint256 bidderABefore = bidderA.balance;
        vm.prank(bidderA);
        auction.withdraw();
        assertEq(bidderA.balance, bidderABefore + 1 ether);
        assertEq(auction.pendingReturns(bidderA), 0);

        // Auction ends — beneficiary receives winning bid
        vm.warp(block.timestamp + DURATION + 1);
        uint256 beneficiaryBefore = beneficiary.balance;
        auction.endAuction();
        assertEq(beneficiary.balance, beneficiaryBefore + 3 ether);
        assertTrue(auction.ended());

        // bidderB withdraws after auction ends
        uint256 bidderBBefore = bidderB.balance;
        vm.prank(bidderB);
        auction.withdraw();
        assertEq(bidderB.balance, bidderBBefore + 2 ether);

        // bidderC was the winner — no pending returns
        assertEq(auction.pendingReturnFor(bidderC), 0);

        // Contract should have zero balance now
        assertEq(address(auction).balance, 0);
    }
}
