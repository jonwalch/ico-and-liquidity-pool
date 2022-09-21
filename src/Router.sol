// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "./Pool.sol";
import "./ICO.sol";

contract Router {
    error DeadlinePassed();
    error InsufficientReserves();
    error InvalidAmount();
    error AddSpcFailed();
    error AddEthFailed();
    error MinSpcNotMet();
    error MinEthNotMet();
    error RefundFailed();
    error TransferPoolTokensFailed();

    ICO private immutable ico; // my ICO contract `is SpaceToken`
    Pool public immutable pool;

    uint16 public FEE_MULTIPLE_TAKE = 990;
    uint16 public FEE_MULTIPLE = 1000;

    modifier beforeDeadline(uint256 time) {
        if (time <= block.timestamp) revert DeadlinePassed();
        _;
    }

    constructor(address _icoAddress, Pool _pool) {
        ico = ICO(_icoAddress);
        pool = _pool;
    }

    function addLiquidity(
        uint256 amountDesiredSpc,
        uint256 amountMinSpc,
        uint256 amountMinEth,
        address to,
        uint256 deadline)
    external payable beforeDeadline(deadline) {
        uint256 ethAmt = msg.value;
        uint256 spcAmt = amountDesiredSpc;

        (uint256 ethReserve, uint256 spcReserve) = getReserves();

        if (!(ethReserve == 0 && spcReserve == 0)) {
            uint256 spcOptimal = quote(msg.value, ethReserve, spcReserve);
            uint256 ethOptimal = quote(amountDesiredSpc, spcReserve, ethReserve);

            if (spcOptimal <= amountDesiredSpc) {
                if (amountMinSpc > spcOptimal) revert MinSpcNotMet();
                spcAmt = spcOptimal;
            } else {
                assert(ethOptimal <= msg.value);
                if (amountMinEth > ethOptimal) revert MinEthNotMet();
                ethAmt = ethOptimal;
            }
        }

        bool result = ico.transferFrom(msg.sender, address(pool), spcAmt);
        if (!result) revert AddSpcFailed();

        (bool resultEth, ) = address(pool).call{value: ethAmt}("");
        if (!resultEth) revert AddEthFailed();

        pool.mint(to);

        if (msg.value > ethAmt) {
            (bool resultRefund, ) = msg.sender.call{value: msg.value - ethAmt}("");
            if (!resultRefund) revert RefundFailed();
        }
    }

    function removeLiquidity(
        uint256 liquidity,
        uint256 amountMinSpc,
        uint256 amountMinEth,
        address to,
        uint256 deadline
    ) external beforeDeadline(deadline) {
        bool result = pool.transferFrom(msg.sender, address(pool), liquidity);
        if (!result) revert TransferPoolTokensFailed();
        (uint256 spcAmount, uint256 etherAmount) = pool.burn(to);
        if (spcAmount < amountMinSpc) revert MinSpcNotMet();
        if (etherAmount < amountMinEth) revert MinEthNotMet();
    }

    function _swap(
        bool ethIn,
        address to
    ) internal {
        (uint256 ethReserve, uint256 spcReserve) = getReserves();
        uint256 ethOut;
        uint256 spcOut;
        uint256 ethAmountIn;
        uint256 spcAmountIn;

        if (ethIn) {
            ethAmountIn = address(pool).balance - ethReserve;
            spcOut = getAmountOut(ethAmountIn, ethReserve, spcReserve);
        } else {
            spcAmountIn = ico.balanceOf(address(pool)) - spcReserve;
            ethOut = getAmountOut(spcAmountIn, spcReserve, ethReserve);
        }

        pool.swap(ethOut, spcOut, to);
    }

    function swapEthForSpc(
        uint256 spcOutMin,
        address to,
        uint256 deadline
    ) external payable beforeDeadline(deadline) {
        (bool resultEth, ) = address(pool).call{value: msg.value}("");
        if (!resultEth) revert AddEthFailed();

        uint256 balance = ico.balanceOf(to);
        _swap(true, to);
        if (ico.balanceOf(to) - balance < spcOutMin) revert MinSpcNotMet();
    }

    function swapSpcForEth(
        uint256 spcIn,
        uint256 ethOutMin,
        address to,
        uint256 deadline
    ) external beforeDeadline(deadline) {
        bool result = ico.transferFrom(msg.sender, address(pool), spcIn);
        if (!result) revert AddSpcFailed();

        uint256 balance = to.balance;
        _swap(false, to);
        if (to.balance - balance < ethOutMin) revert MinEthNotMet();
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256){
        if (amountA == 0) revert InvalidAmount();
        if (reserveA == 0 || reserveB == 0) revert InsufficientReserves();
        return amountA * reserveB / reserveA;
    }

    function getReserves() internal view returns (uint256 ethReserve, uint256 spcReserve) {
        return (pool.etherReserve(), pool.spcReserve());
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal view returns(uint256){
        if (amountIn == 0) revert InvalidAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientReserves();

        uint256 amountInFee = FEE_MULTIPLE_TAKE * amountIn;
        uint256 num = amountInFee * reserveOut;
        uint256 denom = reserveIn * FEE_MULTIPLE + amountInFee;

        return num / denom;
    }

    function spcToEthPrice() external view returns (uint256) {
        return quote(1 ether, pool.etherReserve(), pool.spcReserve());
    }
}
