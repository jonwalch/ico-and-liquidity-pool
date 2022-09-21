pragma solidity ^0.8.13;

import "./SpaceToken.sol";

    error NotOwner();
    error CantAdvancePhase();
    error NotOnAllowlist();
    error CantAppendAllowlist();
    error ContributionsPaused();
    error CantPauseGoalMet();
    error NothingToWithdraw();
    error NotOpenPhase();
    error MustContribute();

    error MaxIndividualSeedExceeded();
    error MaxSeedExceeded();
    error MaxIndividualGeneralExceeded();
    error MaxExceeded();

//TODO: ICO doesn't inherit SpaceToken
contract ICO is SpaceToken {
    enum ICOPhase { SEED, GENERAL, OPEN }

    uint256 private constant TOTAL_ETH_LIMIT = 30_000 ether;
    uint256 private constant SEED_LIMIT = 15_000 ether;
    uint256 private constant SEED_INDIVIDUAL_LIMIT = 1_500 ether;
    uint256 private constant GENERAL_INDIVIDUAL_LIMIT = 1_000 ether;
    uint256 private constant TREASURY_SPC_AMOUNT = 350_000;
    uint256 private constant ICO_SPC_AMOUNT = 150_000;
    // Manually tracking the balance is needed to protect against `selfdestruct(address)` where someone could
    //force ETH into this contract forever trapping SPC within.
    uint256 private balance;
    uint8 private constant TOKEN_RATE = 5;
    uint8 public constant TAX_PERCENT = 2;

    ICOPhase public phase;
    bool private paused;
    //TODO: move to SpaceToken contract
    bool public taxOn;

    address private owner;
    address private treasury;

    mapping(address => uint256) private etherBalances;
    mapping(address => bool) private allowlist;

    event Contribution(address indexed _contributor, uint256 ethAmount, uint256 spcAmount);
    event PhaseShift(ICOPhase phase);
    //TODO: move to SpaceToken contract
    event TaxFlipped(bool on);
    event PauseFlipped(bool on);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address[] memory _allowed, address _owner, address _treasury) SpaceToken("SpaceToken", "SPC", address(this)) {
        owner = _owner;
        treasury = _treasury;

        _transfer(address(this), _treasury, TREASURY_SPC_AMOUNT * 10 ** decimals());

        for (uint i = 0; i < _allowed.length; i++) {
            allowlist[_allowed[i]] = true;
        }
    }

    //TODO: move to SpaceToken contract
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        if (taxOn) {
            uint256 tax = amount * TAX_PERCENT / 100;
            super._transfer(sender, treasury, tax);
            amount -= tax;
        }
        super._transfer(sender, recipient, amount);
    }

    //TODO: take current phase as arg to prevent fat finger
    function progressPhase() external onlyOwner {
        if (phase == ICOPhase.OPEN) revert CantAdvancePhase();

        if (phase == ICOPhase.SEED) {
            phase = ICOPhase.GENERAL;
            emit PhaseShift(ICOPhase.GENERAL);
        } else {
            phase = ICOPhase.OPEN;
            emit PhaseShift(ICOPhase.OPEN);
        }
    }

    //TODO: take current paused value as arg to prevent fat finger
    function flipPaused() external onlyOwner {
        if (!paused && balance == TOTAL_ETH_LIMIT) revert CantPauseGoalMet();
        paused = !paused;
        emit PauseFlipped(paused);
    }

    //TODO: take current tax value as arg to prevent fat finger
    //TODO: move to SpaceToken contract
    function flipTax() external onlyOwner {
        taxOn = !taxOn;
        emit TaxFlipped(taxOn);
    }

    function showBalance() external view returns (uint256) {
        return etherBalances[msg.sender] * TOKEN_RATE;
    }

    function spcLeft() external view returns (uint256) {
        return (ICO_SPC_AMOUNT * 10 ** decimals()) - (balance * TOKEN_RATE);
    }

    function contribute() external payable {
        if (msg.value == 0) revert MustContribute();
        if (paused) revert ContributionsPaused();
        uint256 tempBalance = balance + msg.value;
        if (tempBalance > TOTAL_ETH_LIMIT) revert MaxExceeded();

        if (phase == ICOPhase.SEED) {
            if (tempBalance > SEED_LIMIT) {
                revert MaxSeedExceeded();
            } else if (!allowlist[msg.sender]) {
                revert NotOnAllowlist();
            } else if (etherBalances[msg.sender] + msg.value > SEED_INDIVIDUAL_LIMIT) {
                revert MaxIndividualSeedExceeded();
            }
        } else if (phase == ICOPhase.GENERAL && etherBalances[msg.sender] + msg.value > GENERAL_INDIVIDUAL_LIMIT) {
            revert MaxIndividualGeneralExceeded();
        }

        balance = tempBalance;
        etherBalances[msg.sender] += msg.value;

        emit Contribution(msg.sender, msg.value, msg.value * TOKEN_RATE);
    }

    function withdraw(address to) external {
        if (phase != ICOPhase.OPEN) revert NotOpenPhase();

        uint256 tokensToTransfer = etherBalances[msg.sender] * TOKEN_RATE;
        if (tokensToTransfer == 0) revert NothingToWithdraw();

        etherBalances[msg.sender] = 0;

        // No event needed for withdraw because transfer fires an event
        _transfer(address(this), to, tokensToTransfer);
    }

    //TODO: custom errors
    function ethWithdraw() external {
        require(msg.sender == treasury, "ICO::ethWithdraw: msg.sender must be treasury");

        (bool success, ) = treasury.call{value : address(this).balance}("");
        require(success, "ICO::ethWithdraw: transfer failed");
    }
}
