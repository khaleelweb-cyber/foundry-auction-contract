// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BasicAuction
 * @notice A simple English auction where the highest bidder wins
 * @author IBRAHIM KHALEEL
 */
contract BasicAuction {
    // ─── State variables ───────────────────────────────────────────────
    address public immutable owner;
    address public immutable beneficiary;
    uint256 public auctionEndTime;

    address public highestBidder;
    uint256 public highestBid;

    bool public ended;

    mapping(address => uint256) public pendingReturns;

    // ─── Events ────────────────────────────────────────────────────────
    event NewHighestBid(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);
    event Withdrawal(address indexed bidder, uint256 amount);

    // ─── Errors ────────────────────────────────────────────────────────
    error AuctionAlreadyEnded();
    error BidNotHighEnough(uint256 currentHighestBid);
    error AuctionNotYetEnded();
    error AuctionEndAlreadyCalled();

    // ─── Constructor ───────────────────────────────────────────────────
    constructor() {
        owner = msg.sender;
        beneficiary = 0x42b898c3f62dfDD929f15a8014D4085044e634d7;
        auctionEndTime = block.timestamp + 1 hours;
    }

    // ─── Core functions ────────────────────────────────────────────────

    function bid() external payable {
        if (block.timestamp > auctionEndTime) revert AuctionAlreadyEnded();
        if (msg.value <= highestBid) revert BidNotHighEnough(highestBid);

        if (highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit NewHighestBid(msg.sender, msg.value);
    }

    function withdraw() external returns (bool) {
        uint256 amount = pendingReturns[msg.sender];
        if (amount == 0) return false;

        pendingReturns[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit Withdrawal(msg.sender, amount);
        return true;
    }

    function endAuction() external {
        if (block.timestamp < auctionEndTime) revert AuctionNotYetEnded();
        if (ended) revert AuctionEndAlreadyCalled();

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        (bool success, ) = payable(beneficiary).call{value: highestBid}("");
        require(success, "Transfer to beneficiary failed");
    }

    // ─── View helpers ──────────────────────────────────────────────────

    function timeRemaining() external view returns (uint256) {
        if (block.timestamp >= auctionEndTime) return 0;
        return auctionEndTime - block.timestamp;
    }

    function pendingReturnFor(address bidder) external view returns (uint256) {
        return pendingReturns[bidder];
    }
}
