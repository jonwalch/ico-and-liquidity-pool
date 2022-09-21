// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./ICO.t.sol";
import "../src/Router.sol";

contract RouterTest is ICOTest {
    error DeadlinePassed();
    error InsufficientReserves();
    error InvalidAmount();
    error AddSpcFailed();
    error AddEthFailed();
    error MinSpcNotMet();
    error MinEthNotMet();
    error RefundFailed();

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

    address public constant dude = address(12345);
    address public constant otherDude = address(123456);
    uint256 private constant TREASURY_SPC_AMOUNT = 350_000;
    uint256 public constant ICO_SPC_AMOUNT = 150_000;
    uint256 public constant ICO_ETH_AMOUNT = 30_000 ether;
    uint256 public constant LP_TOKEN_AMOUNT = 67082039324993690892275;
    uint256 internal constant SPC_MAX_SUPPLY = 500_000;

    uint256 public immutable DEADLINE ;
    Router router;
    Pool pool;

    constructor() ICOTest() {
        DEADLINE = block.timestamp + 100;
    }

    function setUp() public override {
        super.setUp();
        pool = new Pool("SpaceToken LP", "SPCLP", ico);
        router = new Router(address(ico), pool);
    }

    function testDeadlinePassedAddLiq() public {
        testSelloutWithdrawToTreasury();
        hoax(treasury); //30k eth, 350k spc
        ico.approve(address(router), ICO_SPC_AMOUNT * decimals);
        hoax(treasury);
        vm.expectRevert(DeadlinePassed.selector);
        router.addLiquidity{value: ICO_ETH_AMOUNT}(
            ICO_SPC_AMOUNT * decimals,
            ICO_SPC_AMOUNT * decimals,
            ICO_ETH_AMOUNT,
            treasury,
            block.timestamp - 1);
    }

    function testDeadlinePassedRemoveLiq() public {
        testSelloutWithdrawToTreasury();
        hoax(treasury); //30k eth, 350k spc
        ico.approve(address(router), ICO_SPC_AMOUNT * decimals);
        hoax(treasury);
        vm.expectRevert(DeadlinePassed.selector);
        router.removeLiquidity(
            100,
            ICO_SPC_AMOUNT * decimals,
            ICO_ETH_AMOUNT * decimals,
            treasury,
            block.timestamp - 1);
    }

    function testSwapEthForSpcDeadlinePassed() public {
        testAddLiquidity();

        hoax(otherDude);
        vm.expectRevert(DeadlinePassed.selector);
        router.swapEthForSpc{value : 1 ether}(1 ether, otherDude, block.timestamp - 1);
    }

    function testSwapSpcForEthDeadlinePassed() public {
        testSwapEthForSpcNoTax();

        hoax(otherDude);
        vm.expectRevert(DeadlinePassed.selector);
        router.swapSpcForEth(1, 1, otherDude, block.timestamp - 1);
    }

    function testAddLiquidity() public {
        testSelloutWithdrawToTreasury();
        hoax(treasury, treasury.balance); //30k eth, 350k spc
        ico.approve(address(router), ICO_SPC_AMOUNT * decimals);

        hoax(treasury, treasury.balance);
        vm.expectEmit(true,true,true,true);
        emit Mint(address(router), treasury, ICO_SPC_AMOUNT * decimals, ICO_ETH_AMOUNT);
        router.addLiquidity{value: ICO_ETH_AMOUNT}(
            ICO_SPC_AMOUNT * decimals,
            ICO_SPC_AMOUNT * decimals,
            ICO_ETH_AMOUNT,
            treasury,
            DEADLINE);

        assertEq(ico.balanceOf(treasury), TREASURY_SPC_AMOUNT * decimals - ICO_SPC_AMOUNT * decimals);
        assertApproxEqAbs(treasury.balance, 0.1 ether, 0.001 ether);
        assertEq(pool.balanceOf(treasury), LP_TOKEN_AMOUNT);
        assertEq(pool.spcReserve(), ICO_SPC_AMOUNT * decimals);
        assertEq(pool.etherReserve(), ICO_ETH_AMOUNT);
        assertEq(pool.totalSupply(), LP_TOKEN_AMOUNT);

        assertEq(router.spcToEthPrice(), 5 ether);
    }

    function testAddLiqTwice() public {
        testSelloutWithdrawToTreasury();
        hoax(treasury, treasury.balance); //30k eth, 350k spc
        ico.approve(address(router), ICO_SPC_AMOUNT * decimals);

        hoax(treasury, treasury.balance);
        router.addLiquidity{value: ICO_ETH_AMOUNT / 2}(
            ICO_SPC_AMOUNT * decimals / 2,
            ICO_SPC_AMOUNT * decimals / 2,
            ICO_ETH_AMOUNT / 2,
            treasury,
            DEADLINE);

        hoax(treasury, treasury.balance);
        router.addLiquidity{value: ICO_ETH_AMOUNT / 2}(
            ICO_SPC_AMOUNT * decimals / 2,
            ICO_SPC_AMOUNT * decimals / 2,
            ICO_ETH_AMOUNT / 2,
            treasury,
            DEADLINE);

        assertEq(ico.balanceOf(treasury), TREASURY_SPC_AMOUNT * decimals - ICO_SPC_AMOUNT * decimals);
        assertApproxEqAbs(treasury.balance, 0.1 ether, 0.001 ether);
        assertEq(pool.balanceOf(treasury), LP_TOKEN_AMOUNT - 1);
        assertEq(pool.spcReserve(), ICO_SPC_AMOUNT * decimals);
        assertEq(pool.etherReserve(), ICO_ETH_AMOUNT);
        assertEq(pool.totalSupply(), LP_TOKEN_AMOUNT - 1);
    }

    function testAddLiqTwiceEthOptRefund() public {
        testSelloutWithdrawToTreasury();
        hoax(treasury, treasury.balance); //30k eth, 350k spc
        ico.approve(address(router), ICO_SPC_AMOUNT * decimals);

        hoax(treasury, treasury.balance);
        router.addLiquidity{value: ICO_ETH_AMOUNT / 2}(
            ICO_SPC_AMOUNT * decimals / 2,
            ICO_SPC_AMOUNT * decimals / 2,
            ICO_ETH_AMOUNT / 2,
            treasury,
            DEADLINE);

        hoax(treasury, treasury.balance);
        router.addLiquidity{value: ICO_ETH_AMOUNT / 2}(
            (ICO_SPC_AMOUNT * decimals / 2) - 1,
            ICO_SPC_AMOUNT * decimals / 2,
            (ICO_ETH_AMOUNT / 2) - 1,
            treasury,
            DEADLINE);

        assertEq(ico.balanceOf(treasury), (TREASURY_SPC_AMOUNT * decimals - ICO_SPC_AMOUNT * decimals) + 1);
        assertApproxEqAbs(treasury.balance, 0.1 ether, 0.001 ether);
        assertEq(pool.balanceOf(treasury), LP_TOKEN_AMOUNT - 4);
        assertEq(pool.spcReserve(), ICO_SPC_AMOUNT * decimals - 1);
        assertEq(pool.etherReserve(), ICO_ETH_AMOUNT - 1);
        assertEq(pool.totalSupply(), LP_TOKEN_AMOUNT - 4);
    }

    function testAddLiqMinSpcNotMet() public {
        testAddLiquidity();

        hoax(treasury, 10 ether);
        vm.expectRevert(MinSpcNotMet.selector);
        router.addLiquidity{value: 10 ether}(
            10_000 * decimals,
            10_000 * decimals + 10_000 * decimals,
            10 ether,
            treasury,
            DEADLINE);
    }

    function testAddLiqMinEthNotMet() public {
        testAddLiquidity();

        hoax(treasury); //30k eth, 350k spc
        ico.approve(address(router), 50 * decimals);

        hoax(treasury, 10 ether);
        vm.expectRevert(MinEthNotMet.selector);
        router.addLiquidity{value: 10 ether}(
            49 * decimals,
            50 * decimals,
            10 ether + 1 wei,
            treasury,
            DEADLINE);
    }

    function testAddLiqTooLow() public {
        hoax(treasury);
        vm.expectRevert(LiquidityTooLow.selector);
        router.addLiquidity(
            0,
            0,
            0,
            treasury,
            DEADLINE);
    }

    function testRemoveLiquidity() public {
        testAddLiquidity();

        hoax(treasury);
        pool.approve(address(router), LP_TOKEN_AMOUNT);

        hoax(treasury);
        vm.expectEmit(true,true,true,true);
        emit Burn(address(router), dude, ICO_SPC_AMOUNT * decimals, ICO_ETH_AMOUNT);
        router.removeLiquidity(
            LP_TOKEN_AMOUNT,
            ICO_SPC_AMOUNT * decimals,
            ICO_ETH_AMOUNT,
            dude,
            DEADLINE
        );

        assertEq(ico.balanceOf(dude), ICO_SPC_AMOUNT * decimals);
        assertApproxEqAbs(dude.balance, 30_000 ether, 0.1 ether);
        assertEq(pool.balanceOf(treasury), 0);
        assertEq(pool.spcReserve(), 0);
        assertEq(pool.etherReserve(), 0);
        assertEq(pool.totalSupply(), 0);
    }

    function testSwapWrongTo() public {
        vm.expectRevert(CantSwapToToken.selector);
        pool.swap(0,0, address(ico));
    }

    function testSwapInsufficientOut() public {
        vm.expectRevert(InsufficientAmountOut.selector);
        pool.swap(0,0, donnie);
    }

    function testSwapDoubleOut() public {
        vm.expectRevert(DoubleOut.selector);
        pool.swap(1,1, donnie);
    }

    function testCantSwapInsufficientReserves() public {
        hoax(treasury);
        vm.expectRevert(InsufficientReserves.selector);
        router.swapEthForSpc{value : 1 ether}(1, treasury, DEADLINE);
    }

    function testCantSwapLiqTooLow() public {
        testAddLiquidity();

        hoax(donnie);
        vm.expectRevert(LiquidityTooLow.selector);
        pool.swap(30_001 ether, 0, donnie);

        hoax(donnie);
        vm.expectRevert(LiquidityTooLow.selector);
        pool.swap(0, (ICO_SPC_AMOUNT + 1) * decimals, donnie);
    }

    function testCantSwapInsufficientAmountIn() public {
        testAddLiquidity();

        hoax(donnie);
        vm.expectRevert(InsufficientAmountIn.selector);
        pool.swap(0, 1, donnie);

        hoax(donnie);
        vm.expectRevert(InsufficientAmountIn.selector);
        pool.swap(1, 0, donnie);
    }

    function testInvalidKSpcIn() public {
        testAddLiquidity();

        // 150_000 spc * 30_000 ether = 4_500_000_000
        // send 1_000 SPC
        // after 1% fee: 150_990 spc * y = 4_500_000_000
        // solve for y = 29803.29823... ether
        // 30_000 - y = 196.701768... ether received

        hoax(donnie);
        ico.transfer(address(pool), 1_000 * decimals);

        hoax(donnie);
        vm.expectRevert(InvalidK.selector);
        pool.swap(196.7018 ether, 0, donnie); // 200 ether with no swap fee or slippage,
    }

    function testInvalidKEthIn() public {
        testAddLiquidity();

        // 150_000 spc * 30_000 ether = 4_500_000_000
        // send 200 ether
        // after 1% fee: 30_198 spc * x = 4_500_000_000
        // solve for x = 14901.6491158354857937611 SPC
        // 150_000 - x =  983.508841645142062389 SPC received

        hoax(donnie, 200.1 ether);
        (bool res, ) = address(pool).call{value: 200 ether}("");
        assert(res);

        hoax(donnie, 10 ether);
        vm.expectRevert(InvalidK.selector);
        pool.swap(0, 983.509 ether, donnie); // 1000 SPC with no slippage or fee
    }

    function testSwapEthForSpcNoTax() public {
        testAddLiquidity();
        // 150_000 spc * 30_000 ether = 4_500_000_000
        // send 1 ether
        // after 1% fee: x * 30_000.99 ether = 4_500_000_000
        // solve for x = 149_995.050163344 SPC (approx)
        //               149995050163344609627882
        // 150_000 - x = 4.94836655390372 SPC received

                              //4_949_836_655_390_372_118
        uint256 amtReceived = 4_949_836_655_390_372_117;

        hoax(otherDude);
        vm.expectEmit(true,true,true,true);
        emit Swap(address(router), otherDude, 0, 1 ether, amtReceived, 0);
        router.swapEthForSpc{value : 1 ether}(amtReceived, otherDude, DEADLINE);

        assertEq(pool.balanceOf(otherDude), 0);
        assertEq(pool.spcReserve(), ICO_SPC_AMOUNT * decimals - amtReceived);
        assertEq(pool.etherReserve(), ICO_ETH_AMOUNT + 1 ether);
        assertEq(ico.balanceOf(otherDude), amtReceived);
    }

    function testSwapEthMinSpcNotMet() public {
        testAddLiquidity();

        uint256 amtReceived = 4_949_836_655_390_372_117;

        hoax(otherDude);
        vm.expectRevert(MinSpcNotMet.selector);
        router.swapEthForSpc{value : 1 ether}(amtReceived + 1, otherDude, DEADLINE);
    }

    function testSwapEthForSpcTax() public {
        testAddLiquidity();
        ico.flipTax();

        // 150_000 spc * 30_000 ether = 4_500_000_000
        // send 1 ether with 1% fee
        // x * 30_000.99 ether = 4_500_000_000
        // solve for x = 14_999.5050163344609627882 SPC
        // 150_000 - x =  4.949836655390372118 SPC calc'ed
        // TransferFrom to user =  4949836655390372118 - 4949836655390372118 * 2 /100
        // 4850839922282564676

        uint256 spcOut = 4949836655390372117;
        uint256 amtReceived = 4850839922282564675; //TODO: less by one
        uint256 tax = spcOut * 2 / 100;

        assertEq(spcOut, amtReceived + tax);

        hoax(otherDude);
        vm.expectEmit(true,true,true,true);
        emit Swap(address(router), otherDude, 0, 1 ether, spcOut, 0);
        router.swapEthForSpc{value : 1 ether}(amtReceived, otherDude, DEADLINE);

        assertEq(pool.balanceOf(otherDude), 0);
        assertEq(pool.spcReserve(), ICO_SPC_AMOUNT * decimals - spcOut);
        assertEq(pool.etherReserve(), ICO_ETH_AMOUNT + 1 ether);
        assertEq(ico.balanceOf(otherDude), amtReceived);
    }

    function testSwapSpcForEthNoTax() public {
        testAddLiquidity();
        // 150_000 spc * 30_000 ether = 4_500_000_000
        // send 1_000 SPC
        // after 1% fee: 150_990 spc * y = 4_500_000_000
        // solve for y = 29803.29823... ether
        // 30_000 - y = 196.701768... ether received
        uint256 amtReceived = 196_701_768_329_028_412_477;

        uint256 spcAmt = 1000 * decimals;
        hoax(treasury);
        ico.transfer(otherDude, spcAmt);

        hoax(otherDude, 10 ether);
        ico.approve(address(router), SPC_MAX_SUPPLY * decimals);
        hoax(otherDude, 10 ether);
        vm.expectEmit(true,true,true,true);
        emit Swap(address(router), otherDude, spcAmt, 0, 0, amtReceived);
        router.swapSpcForEth(spcAmt, amtReceived, otherDude, DEADLINE);

        assertEq(pool.balanceOf(otherDude), 0);
        assertEq(pool.spcReserve(), ICO_SPC_AMOUNT * decimals + spcAmt);
        assertEq(pool.etherReserve(), ICO_ETH_AMOUNT - amtReceived);
        assertEq(ico.balanceOf(otherDude), 0);
        assertEq(otherDude.balance, 10 ether + amtReceived);
    }

    function testSwapSpcMinEthNotMet() public {
        testAddLiquidity();

        uint256 amtReceived = 196_701_768_329_028_412_477;

        uint256 spcAmt = 1000 * decimals;
        hoax(treasury);
        ico.transfer(otherDude, spcAmt);

        hoax(otherDude, 10 ether);
        ico.approve(address(router), SPC_MAX_SUPPLY * decimals);
        hoax(otherDude, 10 ether);
        vm.expectRevert(MinEthNotMet.selector);
        router.swapSpcForEth(spcAmt, amtReceived + 1, otherDude, DEADLINE);
    }

    function testSwapSpcForEthTax() public {
        testAddLiquidity();

        uint256 spcAmt = 1000 * decimals;
        hoax(treasury);
        ico.transfer(otherDude, spcAmt);

        ico.flipTax();

        // 150_000 spc * 30_000 ether = 4_500_000_000
        // send 1000 space
        // TransferFrom to pool tax first: Pool only gets 1000 spc - 1000 spc * 2 / 100 = 980 SPC
        // Swap fee: 980 spc - 980 spc * 1 / 100 = 970.2 Spc
        // 150_970.2 spc * y = 4_500_000_000
        // solve for y = 29807206985219599629595 wei / 29.8 eth
        // 30_000 - y = 192_793_014_780_400_370_405 Eth received

        uint256 amtReceived = 192_793_014_780_400_370_404; // TODO: why am I off by 1?
        uint256 spcTax = spcAmt * 2 / 100;
        uint256 taxedSpcIn = spcAmt - spcTax;

        hoax(otherDude, 10 ether);
        ico.approve(address(router), SPC_MAX_SUPPLY * decimals);
        hoax(otherDude, 10 ether);
        vm.expectEmit(true,true,true,true);
        emit Swap(address(router), otherDude, taxedSpcIn, 0, 0, amtReceived);
        router.swapSpcForEth(spcAmt, amtReceived, otherDude, DEADLINE);

        assertEq(pool.balanceOf(otherDude), 0);
        assertEq(pool.spcReserve(), ICO_SPC_AMOUNT * decimals + taxedSpcIn);
        assertEq(pool.etherReserve(), ICO_ETH_AMOUNT - amtReceived);
        assertEq(ico.balanceOf(otherDude), 0);
        assertEq(otherDude.balance, 10 ether + amtReceived);
    }

}