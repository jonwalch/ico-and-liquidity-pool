// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
//
//import "forge-std/Script.sol";
//import "../src/ICO.sol";
//import "../src/Router.sol";
//import "../src/Pool.sol";
//
//
//contract RouterScript is Script {
//    address constant treasury = REDACTED;
//    address[] private allowlist;
//
//function setUp() public {
//        allowlist = new address[](2);
//        allowlist[0] = treasury;
//        allowlist[1] = REDACTED;
//    }
//
//    function run() public {
//        address[] memory _allowlist = allowlist;
//        vm.startBroadcast();
//
//        ICO ico = new ICO(_allowlist, treasury, treasury);
//        ico.progressPhase();
//        ico.progressPhase();
//        Pool pool = new Pool("SpaceToken LP", "SPCLP", ico);
//        Router router = new Router(address(ico), pool);
//
//        vm.stopBroadcast();
//
//    }
//}
