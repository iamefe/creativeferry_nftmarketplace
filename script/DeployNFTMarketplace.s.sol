// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/NFTMarketplace.sol";

contract DeployNFTMarketplace is Script {
    function run() external returns (NFTMarketplace) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        vm.rememberKey(deployerPrivateKey);
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deploying from account:", deployer);

        NFTMarketplace nftMarketplace = new NFTMarketplace();
        nftMarketplace.initialize();

        vm.stopBroadcast();
        console.log("NFTMarketplace deployed to:", address(nftMarketplace));

        return nftMarketplace;
    }
}
