// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Pool} from "../src/Pool.sol";

contract DeployPool is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("ANVIL_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        uint end = 4 weeks;
        uint256 goal = 10 ether;
        Pool pool = new Pool(end, goal);
        vm.stopBroadcast();
    }
}
