pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./ICO.sol";

contract Pool is ERC20 {
    error NotRouter();
    error Reentrant();
    error LiquidityTooLow();
    error TransferSpcFailed();
    error TransferEthFailed();
    error InvalidK();
    error CantSwapToToken();
    error InsufficientAmountIn();
    error InsufficientAmountOut();
    error DoubleOut();

    event Mint(address indexed sender, address indexed to, uint256 spcAmount, uint256 etherAmount);
    event Burn(address indexed sender, address indexed to, uint256 spcAmount, uint256 etherAmount);
    event Swap(
        address indexed sender,
        address indexed to,
        uint256 spcAmountIn,
        uint256 etherAmountIn,
        uint256 spcAmountOut,
        uint256 etherAmountOut);

    uint256 public spcReserve;
    uint256 public etherReserve;

    ICO private immutable ico;

    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private enterStatus;

    uint16 public constant FEE_TAKE = 10;
    uint16 public constant FEE_MULTIPLE = 1000;

    modifier nonReentrant() {
        if (enterStatus == ENTERED) revert Reentrant();
        enterStatus = ENTERED;
        _;
        enterStatus = NOT_ENTERED;
    }

    receive() external payable {} // TODO: remove and just make mint and swap payable

    constructor (string memory name, string memory symbol, ICO _ico) ERC20(name, symbol) {
        ico = _ico;
        enterStatus = NOT_ENTERED;
    }

    function mint(address to) external nonReentrant {
        uint256 liquidity;
        uint256 supply = totalSupply();
        uint256 _spcReserve = spcReserve;
        uint256 _etherReserve = etherReserve;

        uint256 spcBalance = ico.balanceOf(address(this));
        uint256 etherBalance = address(this).balance;

        uint256 spcAmount = spcBalance - _spcReserve;
        uint256 etherAmount = etherBalance - _etherReserve;

        if (supply > 0) {
            uint256 spcLiquidity = spcAmount * supply / _spcReserve;
            uint256 etherLiquidity = etherAmount * supply / _etherReserve;
            liquidity = spcLiquidity < etherLiquidity ? spcLiquidity : etherLiquidity;
        } else {
            liquidity = sqrt(spcAmount * etherAmount);
        }

        if (liquidity == 0) revert LiquidityTooLow();

        _mint(to, liquidity);
        _update(spcBalance, etherBalance);
        emit Mint(msg.sender, to, spcAmount, etherAmount);
    }

    function burn(address to) external nonReentrant returns(uint256 spcAmount, uint256 etherAmount) {
        uint256 supply = totalSupply();
        uint256 spcBalance = ico.balanceOf(address(this));
        uint256 etherBalance = address(this).balance;
        uint256 liquidity = balanceOf(address(this));

        spcAmount = liquidity * spcBalance / supply;
        etherAmount = liquidity * etherBalance / supply;

        bool result = ico.transfer(to, spcAmount);
        if (!result) revert TransferSpcFailed();
        (bool resultEth,) = to.call{value: etherAmount}("");
        if (!resultEth) revert TransferEthFailed();

        _burn(address(this), liquidity);
        // following transfers, pass in new balances to update reserves
        _update(ico.balanceOf(address(this)), address(this).balance);
        emit Burn(msg.sender, to, spcAmount, etherAmount);
    }

    function swap(uint256 ethOut, uint256 spcOut, address to) external nonReentrant {
        if (to == address(ico)) revert CantSwapToToken();
        if (ethOut == 0 && spcOut == 0) revert InsufficientAmountOut();
        if (ethOut > 0 && spcOut > 0) revert DoubleOut();

        uint256 _spcReserve = spcReserve;
        uint256 _etherReserve = etherReserve;
        if (_spcReserve <= spcOut || _etherReserve <= ethOut) revert LiquidityTooLow();

        uint256 spcAmountIn;
        uint256 ethAmountIn;
        uint256 spcBalance = ico.balanceOf(address(this));
        uint256 ethBalance = address(this).balance;

        if (ethOut > 0) {
            spcAmountIn = spcBalance - _spcReserve; // spcOut will be zero
        } else {
            ethAmountIn = ethBalance - _etherReserve; //ethOut will be zero
        }

        if (spcAmountIn == 0 && ethAmountIn == 0) revert InsufficientAmountIn();

        if (ethOut > 0){
            (bool result,) = to.call{value: ethOut}("");
            if (!result) revert TransferEthFailed();
            ethBalance -= ethOut;
        } else {
            bool result = ico.transfer(to, spcOut);
            if (!result) revert TransferSpcFailed();
            spcBalance -= spcOut; //could also call balanceOf
        }

        { // scoped to avoid CompilerError: Stack too deep.
            uint256 feeSpcBalance = spcBalance * FEE_MULTIPLE - spcAmountIn * FEE_TAKE;
            uint256 feeEthBalance = ethBalance * FEE_MULTIPLE - ethAmountIn * FEE_TAKE;
            if (feeEthBalance * feeSpcBalance < _spcReserve * _etherReserve * FEE_MULTIPLE * FEE_MULTIPLE) revert InvalidK();
        }

        _update(spcBalance, ethBalance);
        emit Swap(msg.sender, to, spcAmountIn, ethAmountIn, spcOut, ethOut);
    }

    function _update(uint256 spcBalance, uint256 etherBalance) internal {
        spcReserve = spcBalance;
        etherReserve = etherBalance;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

}
