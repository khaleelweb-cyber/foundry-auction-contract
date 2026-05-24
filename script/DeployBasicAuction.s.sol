// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {BasicAuction} from "../src/BasicAuction.sol";

contract DeployBasicAuction is Script {
    function run() external returns (BasicAuction) {
        vm.startBroadcast();

        BasicAuction auction = new BasicAuction();

        vm.stopBroadcast();

        console.log("BasicAuction deployed at:", address(auction));
        console.log("Owner:                   ", auction.owner());
        console.log("Beneficiary:             ", auction.beneficiary());
        console.log("Auction ends at:         ", auction.auctionEndTime());
        console.log("Time remaining (seconds):", auction.timeRemaining());

        return auction;
    }
}
