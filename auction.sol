// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

contract Auction {
    address payable public auctioneer;
    uint public stBlock; // start block
    uint public etBlock; // end block

    enum AuctionState { Started, Running, Ended, Cancelled }
    AuctionState public auctionState;

    uint public highestBid;
    uint public highestPayableBid;
    uint public bidInc;

    address payable public highestBidder;

    mapping(address => uint) public bids;

    constructor() {
        auctioneer = payable(msg.sender);
        auctionState = AuctionState.Running;
        stBlock = block.number;
        etBlock = stBlock + 240; // 240 blocks for the auction duration
        bidInc = 1 ether;
    }

    modifier notOwner() {
        require(msg.sender != auctioneer, "Owner cannot bid");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == auctioneer, "Only the auctioneer can perform this action");
        _;
    }

    modifier hasStarted() {
        require(block.number >= stBlock, "Auction has not started yet");
        _;
    }

    modifier beforeEnding() {
        require(block.number < etBlock, "Auction has already ended");
        _;
    }

    function cancelAuction() public onlyOwner hasStarted {
        require(auctionState == AuctionState.Running, "Auction is not currently running");
        auctionState = AuctionState.Cancelled;
    }

    function endAuction() public onlyOwner hasStarted {
        require(auctionState == AuctionState.Running, "Auction is not currently running");
        auctionState = AuctionState.Ended;
    }

    function min(uint a, uint b) private pure returns (uint) {
        return a <= b ? a : b;
    }

    function bid() payable public notOwner hasStarted beforeEnding {
        require(auctionState == AuctionState.Running, "Auction is not currently running");
        require(msg.value >= 1 ether, "Minimum bid is 1 ether");

        uint currentBid = bids[msg.sender] + msg.value;
        require(currentBid > highestBid, "Bid must be higher than the current highest bid");

        // Update the highestBid and highestBidder
        highestBid = currentBid;
        highestBidder = payable(msg.sender);

        // Update the highestPayableBid
        highestPayableBid = min(highestBid + bidInc, currentBid);

        bids[msg.sender] = currentBid;
    }

    function finalizeAuction() public {
        require(
            auctionState == AuctionState.Cancelled ||
            auctionState == AuctionState.Ended ||
            block.number >= etBlock,
            "Auction has not ended or not yet cancelled"
        );
        require(msg.sender == auctioneer || bids[msg.sender] > 0, "You are not authorized to finalize");

        address payable person;
        uint value;

        if (auctionState == AuctionState.Cancelled) {
            person = payable(msg.sender);
            value = bids[msg.sender];
        } else {
            if (msg.sender == auctioneer) {
                person = auctioneer;
                value = highestPayableBid;
            } else {
                if (msg.sender == highestBidder) {
                    person = highestBidder;
                    value = bids[highestBidder] - highestPayableBid;
                } else {
                    person = payable(msg.sender);
                    value = bids[msg.sender];
                }
            }
        }

        // Transfer funds to the respective person
        bids[msg.sender] = 0;
        person.transfer(value);
    }
}
