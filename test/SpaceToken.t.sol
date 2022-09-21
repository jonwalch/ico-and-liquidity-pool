// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {SpaceToken} from "../src/SpaceToken.sol";

contract SpaceTokenTest is Test {
    address public constant deployer = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    uint256 public constant supply = 500_000_000_000_000_000_000_000;
    SpaceToken public sp;

    function setUp() public {
        sp = new SpaceToken("SpaceToken", "SPC", deployer);
    }

    function testMaxSupply() public {
        assertEq(sp.balanceOf(deployer), supply);
    }
}
