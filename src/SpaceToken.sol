// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract SpaceToken is ERC20 {

    uint256 internal constant MAX_SUPPLY = 500_000;

    constructor(string memory name, string memory symbol, address to) ERC20(name, symbol) {
        _mint(to, MAX_SUPPLY * 10 ** decimals());
    }
}
