// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ICO.sol";

contract ICOTest is Test {
    enum ICOPhase { SEED, GENERAL, OPEN }
    uint256 public immutable decimals;
    uint8 public constant TOKEN_RATE = 5;
    uint8 public constant TAX_RATE = 2;
    uint256 public constant TREASURY_AMOUNT = 350_000;
    uint256 public constant ICO_AMOUNT = 150_000;

    address public constant deployer = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    address public constant treasury = address(100_000_000);

    address public constant alice = address(200_000_000);
    address public constant bob = address(300_000_000);
    address public constant ronnie = address(400_000_000);
    address public constant donnie = address(500_000_000);
    address public constant jonny = address(600_000_000);

    address public constant one = address(1);
    address public constant two = address(2);
    address public constant three = address(3);
    address public constant four = address(4);
    address public constant five = address(5);
    address public constant six = address(6);
    address public constant seven = address(7);
    address public constant eight = address(8);
    address public constant nine = address(9);
    address public constant ten = address(10);
    address public constant eleven = address(11);
    address public constant twelve = address(12);
    address public constant thirteen = address(13);
    address public constant fourteen = address(14);
    address public constant fifteen = address(15);
    address public constant sixteen = address(16);
    address public constant seventeen = address(17);
    address public constant eighteen = address(18);
    address public constant nineteen = address(19);
    address public constant twenty = address(20);
    address public constant twentyone = address(21);
    address public constant twentytwo = address(22);
    address public constant twentythree = address(23);
    address public constant twentyfour = address(24);
    address public constant twentyfive = address(25);
    address public constant twentysix = address(26);
    address public constant twentyseven = address(27);
    address public constant twentyeight = address(28);

    uint256 public constant supply = 500_000_000_000_000_000_000_000;
    ICO public ico;

    address[] public allow;
    address[] public users;

    event Contribution(address indexed _contributor, uint256 ethAmount, uint256 spcAmount);
    event PhaseShift(ICOPhase phase);
    event TaxFlipped(bool on);
    event PauseFlipped(bool on);

    constructor() {
        decimals = 10 ** 18;
    }

    //TODO: find a cleaner way to do this
    function setUp() public virtual {
        address[] memory _users = new address[](31);
        _users[0] = ronnie;
        _users[1] = donnie;
        _users[2] = jonny;
        _users[3] = one;
        _users[4] = two;
        _users[5] = three;
        _users[6] = four;
        _users[7] = five;
        _users[8] = six;
        _users[9] = seven;
        _users[10] = eight;
        allow = _users;

        _users[11] = nine;
        _users[12] = ten;
        _users[13] = eleven;
        _users[14] = twelve;
        _users[15] = thirteen;
        _users[16] = fourteen;
        _users[17] = fifteen;
        _users[18] = sixteen;
        _users[19] = seventeen;
        _users[20] = eighteen;
        _users[21] = nineteen;
        _users[22] = twenty;
        _users[23] = twentyone;
        _users[24] = twentytwo;
        _users[25] = twentythree;
        _users[26] = twentyfour;
        _users[27] = twentyfive;
        _users[28] = twentysix;
        _users[29] = twentyseven;
        _users[30] = twentyeight;

        users = _users;

        ico = new ICO(allow, deployer, treasury);
    }

    function testTreasuryBalance() public {
        assertEq(ico.balanceOf(address(ico)), ICO_AMOUNT * decimals);
        assertEq(ico.balanceOf(address(ico)), ico.spcLeft());
        assertEq(ico.balanceOf(treasury), TREASURY_AMOUNT * decimals);
    }

    function testOnlyOwnerProgressPhase() public {
        vm.expectRevert(NotOwner.selector);
        vm.prank(treasury);
        ico.progressPhase();
    }

    function testOnlyOwnerPaused() public {
        vm.expectRevert(NotOwner.selector);
        vm.prank(alice);
        ico.flipPaused();
    }

    function testOnlyOwnerTax() public {
        vm.expectRevert(NotOwner.selector);
        vm.prank(bob);
        ico.flipTax();
    }

    function testOnlyOwnerTaxSuccess() public {
        vm.expectEmit(true,true,true,true);
        emit TaxFlipped(true);
        ico.flipTax();
    }

    function testOwnerCantProgressPhase() public {
        vm.expectEmit(true,true,true,true);
        emit PhaseShift(ICOPhase.GENERAL);
        ico.progressPhase();

        vm.expectEmit(true,true,true,true);
        emit PhaseShift(ICOPhase.OPEN);
        ico.progressPhase();

        vm.expectRevert(CantAdvancePhase.selector);
        ico.progressPhase();
    }

    function testMustContribute() public {
        vm.expectRevert(MustContribute.selector);
        hoax(bob, 100 ether);

        ico.contribute();
    }

    function testNotOnAllowlist() public {
        vm.expectRevert(NotOnAllowlist.selector);
        hoax(bob, 100 ether);

        ico.contribute{value: 1 ether}();
    }

    function testPaused() public {
        ico.flipPaused();

        hoax(donnie, 100 ether);
        vm.expectRevert(ContributionsPaused.selector);
        ico.contribute{value: 1 ether}();
    }

    function testCanAdvanceWhenPaused() public {
        ico.flipPaused();
        ico.progressPhase();
    }

    function testUnpaused() public {
        vm.expectEmit(true,true,true,true);
        emit PauseFlipped(true);
        ico.flipPaused();

        vm.expectEmit(true,true,true,true);
        emit PauseFlipped(false);
        ico.flipPaused();

        hoax(donnie, 100 ether);
        ico.contribute{value: 1 ether}();
    }

    function testMaxSeedIndivExceeded() public {
        vm.expectRevert(MaxIndividualSeedExceeded.selector);
        hoax(ronnie, 1502 ether);

        ico.contribute{value: 1501 ether}();
    }

    function testMaxSeedIndivNotExceeded() public {
        hoax(ronnie, 1502 ether);

        ico.contribute{value: 1500 ether}();
    }

    function testMaxSeedIndivExceededGeneralExceeded() public {
        hoax(ronnie, 1501 ether);
        vm.expectEmit(true, true, true, true);
        emit Contribution(ronnie, 1500 ether, 1500 * 5 ether);
        ico.contribute{value: 1500 ether}();

        hoax(deployer, 1 ether);
        ico.progressPhase();

        hoax(ronnie, 1 ether);

        vm.expectRevert(MaxIndividualGeneralExceeded.selector);
        ico.contribute{value: 1 wei}();

        assertEq(address(ico).balance, 1_500 ether);
    }

    function testOpenLimitLifted() public {
        hoax(ronnie, 1501 ether);
        ico.contribute{value: 1500 ether}();

        ico.progressPhase();
        ico.progressPhase();

        hoax(ronnie, 1 ether);
        ico.contribute{value: 1 wei}();

        // 15 eth and 1 wei
        assertEq(address(ico).balance, 1_500_000_000_000_000_000_001 wei);
    }

    function testMaxSeedExceeded() public {

        // First ten allowlist users
        for (uint i = 0; i < 10; i++) {
            hoax(allow[i], 1501 ether);
            ico.contribute{value: 1500 ether}();
        }

        //last allowlist
        hoax(eight, 1 ether);
        vm.expectRevert(MaxSeedExceeded.selector);
        ico.contribute{value: 1 wei}();

        assertEq(address(ico).balance, 15_000 ether);
    }

    function testMaxGeneralExceeded() public {
        ico.progressPhase();

        for (uint i = 0; i < 30; i++) {
            hoax(users[i], 1001 ether);
            ico.contribute{value: 1000 ether}();
        }

        hoax(twentyseven, 1001 ether);
        vm.expectRevert(MaxExceeded.selector);
        ico.contribute{value: 1 wei}();

        assertEq(address(ico).balance, 30_000 ether);
    }

    function testMaxOpenExceeded() public {
        ico.progressPhase();
        ico.progressPhase();

        hoax(alice, 30_001 ether);
        ico.contribute{value: 30_000 ether}();

        hoax(alice, 1 ether);
        vm.expectRevert(MaxExceeded.selector);
        ico.contribute{value: 1 wei}();

        assertEq(address(ico).balance, 30_000 ether);

        vm.expectRevert(CantPauseGoalMet.selector);
        ico.flipPaused();
    }


    function testFailDeployerNoBalance() public {
        hoax(donnie, 1501 ether);
        ico.contribute{value: 1500 ether}();

        assertEq(address(ico).balance, 1500 ether);

        //deployer tries transferring
        ico.transfer(bob, 1);
    }

    function testCantWithdrawBeforeOpen() public {
        uint256 tknAmt = 7500000000000000000000;
        hoax(donnie, 1501 ether);
        ico.contribute{value: 1500 ether}();

        assertEq(address(ico).balance, 1500 ether);

        hoax(donnie);
        vm.expectRevert(NotOpenPhase.selector);
        ico.withdraw(donnie);

        ico.progressPhase(); // move to GENERAL

        hoax(donnie);
        vm.expectRevert(NotOpenPhase.selector);
        ico.withdraw(donnie);

        ico.progressPhase(); // move to OPEN

        hoax(donnie);
        ico.withdraw(donnie);
        assertEq(ico.balanceOf(donnie), tknAmt);

        hoax(donnie);
        ico.transfer(bob, tknAmt);
        assertEq(ico.balanceOf(donnie), 0);
        assertEq(ico.balanceOf(bob), tknAmt);
    }

    function testFailWithdrawZeroAddress() public {
        ico.progressPhase();
        ico.progressPhase();

        hoax(donnie, 1501 ether);
        ico.contribute{value: 1500 ether}();

        hoax(donnie);
        ico.withdraw(address(0));
    }

    function testWithdrawAlreadyWithdrew() public {
        ico.progressPhase();
        ico.progressPhase();

        hoax(donnie, 1501 ether);
        ico.contribute{value: 1500 ether}();

        hoax(donnie);
        ico.withdraw(donnie);

        hoax(donnie);
        vm.expectRevert(NothingToWithdraw.selector);
        ico.withdraw(donnie);
    }

    function testWithdrawNeverContributed() public {
        ico.progressPhase();
        ico.progressPhase();

        hoax(donnie);
        vm.expectRevert(NothingToWithdraw.selector);
        ico.withdraw(donnie);
    }

    function testMinContribution() public {
        hoax(jonny, 1 ether);
        ico.contribute{value: 1 wei}();
    }

    function testBalancesCorrectOnWithdrawal() public {
        ico.progressPhase();
        ico.progressPhase();

        for (uint i = 0; i < 30; i++) {
            hoax(users[i], 1001 ether);
            ico.contribute{value: 1000 ether}();
            hoax(users[i], 1 ether);
            ico.withdraw(users[i]);
            assertEq(ico.balanceOf(users[i]), 1000 * TOKEN_RATE * decimals);
        }
        assertEq(ico.balanceOf(address(ico)), 0);
        assertEq(ico.balanceOf(address(ico)), ico.spcLeft());
    }

    function testWithdrawDifferentTo() public {
        ico.progressPhase();
        ico.progressPhase();
        hoax(jonny, 1.01 ether);
        ico.contribute{value: 1 ether}();

        uint256 balance = 1 * TOKEN_RATE * decimals;

        hoax(jonny, 1.01 ether);
        assertEq(ico.showBalance(), balance);

        hoax(jonny, 1.01 ether);
        ico.withdraw(donnie);
        assertEq(ico.balanceOf(donnie), 1 * balance);
        assertEq(ico.balanceOf(address(ico)), ICO_AMOUNT * decimals - balance);
        assertEq(ico.balanceOf(address(ico)), ico.spcLeft());

        hoax(jonny, 1.01 ether);
        assertEq(ico.showBalance(), 0);
    }

    function testTax() public {
        ico.flipTax();
        ico.progressPhase();
        ico.progressPhase();

        hoax(jonny, 1.01 ether);
        ico.contribute{value: 1 ether}();
        hoax(jonny, 1.01 ether);
        ico.withdraw(jonny);

        uint256 taxAmt = 1 * TOKEN_RATE * decimals * TAX_RATE / 100;
        uint256 jAmt = 1 * TOKEN_RATE * decimals - taxAmt;
        uint256 treasuryAmt = TREASURY_AMOUNT * decimals + taxAmt;

        assertEq(ico.balanceOf(jonny), jAmt);
        assertEq(ico.balanceOf(treasury), treasuryAmt);

        jAmt = jAmt / 2;
        treasuryAmt += jAmt * TAX_RATE / 100;
        uint256 aliceAmt = jAmt - jAmt * TAX_RATE / 100;
        hoax(jonny);
        ico.transfer(alice, jAmt);

        assertEq(ico.balanceOf(jonny), jAmt);
        assertEq(ico.balanceOf(alice), aliceAmt);
        assertEq(ico.balanceOf(treasury), treasuryAmt);

        ico.flipTax(); // turn taxes off

        hoax(alice);
        ico.transfer(donnie, aliceAmt);

        assertEq(ico.balanceOf(alice), 0);
        assertEq(ico.balanceOf(donnie), aliceAmt);
        assertEq(ico.balanceOf(treasury), treasuryAmt);
    }

    function testContributionLimits () public {
        hoax(donnie, 1501 ether);
        ico.contribute{value: 1500 ether}();

        ico.progressPhase();

        hoax(donnie, 1 ether);
        vm.expectRevert(MaxIndividualGeneralExceeded.selector);
        ico.contribute{value: 1 wei}();

        ico.progressPhase();

        hoax(donnie, 30_001 ether);
        ico.contribute{value: 28_500 ether}();

        assertEq(address(ico).balance, 30_000 ether);
    }

    function testCanContribute () public {
        hoax(donnie, 1000 ether);
        ico.contribute{value: 999 ether}();

        ico.progressPhase();

        hoax(donnie, 1.01 ether);
        ico.contribute{value: 1 ether}();

        hoax(donnie, 1 ether);
        vm.expectRevert(MaxIndividualGeneralExceeded.selector);
        ico.contribute{value: 1 wei}();

        ico.progressPhase();

        hoax(donnie, 30_001 ether);
        ico.contribute{value: 29_000 ether}();

        assertEq(address(ico).balance, 30_000 ether);

    }

    function testSelloutWithdrawToTreasury() public {
        ico.progressPhase();
        ico.progressPhase();

        for (uint i = 0; i < 30; i++) {
            hoax(users[i], 1001 ether);
            ico.contribute{value: 1000 ether}();
            hoax(users[i], 1 ether);
            ico.withdraw(users[i]);
            assertEq(ico.balanceOf(users[i]), 1000 * TOKEN_RATE * decimals);
        }
        assertEq(ico.balanceOf(address(ico)), 0);
        assertEq(ico.balanceOf(address(ico)), ico.spcLeft());
        assertEq(treasury.balance, 0);
        assertEq(address(ico).balance, 30_000 ether);

        hoax(treasury, 0.1 ether);
        ico.ethWithdraw();
        assertApproxEqAbs(treasury.balance, 30_000 ether, 0.1 ether);
    }

    //TODO fuzzing

}
