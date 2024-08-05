// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Sukuk {
    struct Investor {
        address investorAddress;
        uint256 numberOfSukuk;
        uint256 value;
        uint256 allowed;
    }

    mapping(address => uint256) public addressToAmountFunded;
    mapping(address => uint256) public addressToAmountDeposited;
    address payable[] public investors;
    address public admin;
    AggregatorV3Interface public priceFeed;
    address payable public ijaara;
    uint256 public sukukPrice;
    Investor[] public investorList;

    mapping(address => Investor) public investorInfo;

    enum SukukState {
        COOLDOWN,
        OPEN,
        ISSUE,
        CLOSED,
        REDEEM_PERIOD
    }

    SukukState public sukukState;
    uint256 public constant DEFAULT_SUKUK_PRICE = 100 * 10**18;

    event SukukStarted(uint256 sukukPrice);
    event SukukIssued();
    event SukukEndIssue();
    event SukukRedeemStarted();
    event SukukPurchased(address indexed investor, uint256 numberOfSukuk, uint256 value);
    event SukukRedeemed(address indexed investor, uint256 numberOfSukuk, uint256 value);
    event IjaaraSet(address indexed ijaara);
    event Withdrawn(uint256 amount);
    event Deposited(address indexed ijaara, uint256 amount);

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        admin = msg.sender;
        sukukState = SukukState.CLOSED;
        sukukPrice = DEFAULT_SUKUK_PRICE;
    }

    function getExpectedPrice(uint256 _numberOfSukuk) public view returns (uint256) {
        uint256 _sukukPrice = getEntranceFee();
        uint256 expectedPrice = _sukukPrice * _numberOfSukuk;
        return expectedPrice;
    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10; // 18 decimals
        uint256 costToEnter = (sukukPrice * 10**18) / adjustedPrice;
        return costToEnter;
    }

    function startSukuk() public onlyAdmin {
        require(sukukState == SukukState.CLOSED, "Can't issue new sukuk yet");
        sukukState = SukukState.OPEN;
        emit SukukStarted(sukukPrice);
    }

    function issueSukuk() public onlyAdmin {
        require(sukukState == SukukState.OPEN, "Can't issue new sukuk yet");
        sukukState = SukukState.ISSUE;
        emit SukukIssued();
    }

    function endIssue() public onlyAdmin {
        require(sukukState == SukukState.ISSUE, "Invalid state");
        sukukState = SukukState.COOLDOWN;
        emit SukukEndIssue();
    }

    function startRedeem() public onlyAdmin {
        require(sukukState == SukukState.COOLDOWN, "Invalid state");
        sukukState = SukukState.REDEEM_PERIOD;
        emit SukukRedeemStarted();
    }

    function purchaseSukuk(uint256 _numberOfSukuk) public payable {
        uint256 expectedPrice = getExpectedPrice(_numberOfSukuk);
        require(expectedPrice == msg.value, "Send the correct amount of ETH");
        investorList.push(Investor(msg.sender, _numberOfSukuk, msg.value, 1));
        emit SukukPurchased(msg.sender, _numberOfSukuk, msg.value);
    }

    function redeemSukuk(uint256 _numberOfSukuk) public {
        require(sukukState == SukukState.REDEEM_PERIOD, "Redemption not allowed at this time");
        require(investorInfo[msg.sender].numberOfSukuk >= _numberOfSukuk, "Insufficient sukuk to redeem");
        uint256 refundAmount = investorInfo[msg.sender].value * _numberOfSukuk / investorInfo[msg.sender].numberOfSukuk;
        investorInfo[msg.sender].numberOfSukuk -= _numberOfSukuk;
        payable(msg.sender).transfer(refundAmount);
        emit SukukRedeemed(msg.sender, _numberOfSukuk, refundAmount);
    }

    function setIjaara(address payable _ijaara) public onlyAdmin {
        ijaara = _ijaara;
        emit IjaaraSet(_ijaara);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyIjaara() {
        require(msg.sender == ijaara, "Only ijaara can perform this action");
        _;
    }

    function getAdminAddress() public view returns (address) {
        return admin;
    }

    function getIjaaraAddress() public view returns (address) {
        return ijaara;
    }

    function withdraw() public payable onlyIjaara {
        uint256 amount = address(this).balance;
        ijaara.transfer(amount);
        emit Withdrawn(amount);
    }

    function deposit() public payable onlyIjaara {
        addressToAmountDeposited[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

