//SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./token.sol";

contract tokenSale is Token, ReentrancyGuard {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    
    AggregatorV3Interface internal priceFeed;
    
    address public tokenAddress;
    address public saleWallet = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;// 0xc5625D68C341E336aC0096D10a0bE52D68e7011b;
    Token public tokenContract;
    
    bool public saleStarted;
    bool public isSaleOn;
    bool public saleEnded;
    uint public minInvestment;
    uint public startTime;
    uint public endTime;
    uint public totalWeiraised;
    
    mapping(address => bool) public whiteList;
    mapping(address => uint) public investments;//investments by the buyers in wei
    
    event Initialized();
    event SaleEnded();
    event SaleResumed();
    event SalePaused();
    event TokensPurchased(address _buyer, uint _cost, uint _tokens, uint _refund);
    event InvestorWhitelisted(address investor);
    event investorBlackListed(address);

    constructor(address _tokenAddress)
    {
        tokenAddress = _tokenAddress;
        tokenContract = Token(tokenAddress);
        priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        saleStarted = false;
        saleEnded = false;
        isSaleOn = false;
        minInvestment  = 1;//USD
    }
    
    modifier isWhitelisted(address add) {
        require(whiteList[add], "Not whitelisted");
        _;
    }
    
    modifier saleState() {
        require(saleStarted, "Sale has not started yet");
        require(isSaleOn, "Sale is not on right now");
        require(!saleEnded, "Sale has ended");
        _;
    }
    
    function initialize() external onlyOwner
    {
        require(!saleStarted, "Sale has already started");
        uint tokenBalance = tokenContract.balanceOf(saleWallet);
        uint allowance = tokenContract.allowance(saleWallet, address(this));
        
        require(allowance >= tokenBalance, "increase allowance to the saleWallet balance");
        
        saleStarted = true;
        isSaleOn = true;
        startTime = block.timestamp;
        endTime = startTime.add(5184000); // startTime + 60days
        
        emit Initialized();
    }
    
    function pauseSale() external onlyOwner saleState {
        isSaleOn = false;
        emit SalePaused();
    }
    
    function resumeSale() external onlyOwner {
        require(saleStarted, "Sale has not started yet");
        require(!saleEnded, "Sale has ended");
        require(!isSaleOn, "Sale is already on right now");
        
        isSaleOn = true;
        
        emit SaleResumed();
    }
    
    //to whitelist multiple addresses
    function whiteListMulti(address[] memory adds) external onlyOwner {
       for (uint i = 0; i < adds.length; i++) {
            whiteList[adds[i]] = true;
            
            emit InvestorWhitelisted(adds[i]);
       }
    }
    
    //to whiteList one address
    function whiteListOne(address add) external onlyOwner {
        require(!whiteList[add],"already whitelisted");
        whiteList[add] = true;
        
        emit InvestorWhitelisted(add);
    }
    
    //to blackList one address
    function blackListOne(address add) external onlyOwner isWhitelisted(add) {
        whiteList[add] = false;
        
        emit investorBlackListed(add);
    }
    
    function getThePrice() public view onlyOwner() returns (int) {
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }
    
    //returns the amount of TKN you can get for 1ETH
    function getETHconversion() public view returns (uint) {
        uint ethPrice = uint(getThePrice());
        uint tokenPriceDivisor = 1000; // 1TKN = $0.001 
        
        uint rate = ethPrice.div(10**8).mul(tokenPriceDivisor); // 1ETH = ethPrice(in USD)/0.001(USD) TKN
        
        return rate;
    }
    
    //returns the value of tokens in wei
    function getTokenPrice(uint tokens) internal view returns (uint) {
        uint rate = getETHconversion();
        
        uint price = tokens.div(rate);
        
        return price;
    }
    
    function getBonusPercentage() internal view returns (uint) {
        uint currentTime = block.timestamp;
        
        if(currentTime < startTime.add(1296000)) //startTime + 15 days, i.e. PrivateSale duration
        {
            return uint(25);
        }
        
        if(currentTime < startTime.add(2592000)) //startTime + 30 days, i.e. PrivateSale duration
        {
            return uint(20);
        }
        
        if(currentTime < startTime.add(3196800)) //startTime + 37 days, i.e. 1st week CrowdSale duration
        {
            return uint(15);
        }
        
        if(currentTime < startTime.add(3801600)) //startTime + 44 days, i.e. 2nd week CrowdSale duration
        {
            return uint(10);
        }
        
        if(currentTime < startTime.add(4406400)) //startTime + 51 days, i.e. 3rd week CrowdSale duration
        {
            return uint(5);
        }
        
        return uint(0);
    }
    
    function buyToken(address buyer) public payable isWhitelisted(buyer) saleState {
        
        require(block.timestamp < endTime, "The sale has ended");
        
        require(msg.sender != address(saleWallet),"Can't buy from saleWallet");
        require(buyer != saleWallet,"Can't buy for saleWallet");
        require(buyer != address(0),"Can't buy for dead address");
        require(buyer != tokenAddress, "Can't buy for the token contract");
        
        uint256 saleBalance = tokenContract.balanceOf(saleWallet);
        require(saleBalance > 0, "Not enough tokens left in the wallet");
        
        uint refund = 0;
        uint cost = msg.value;
        uint costUSD = (uint(getThePrice()).div(10**8)).mul(cost.div(10**18));
        
        require(costUSD >= minInvestment,"buy atleast $1 worth of TKN");
        
        uint rate = getETHconversion();
        uint tokens = cost.mul(rate);  //cost = (cost/10^18) * (rate * 10^18)
        
        uint bonusPercentage = getBonusPercentage();
        uint bonusTokens = tokens.mul(bonusPercentage).div(100);
        tokens = tokens.add(bonusTokens); 
        
        if(tokens > saleBalance)
        {
            uint remainingTokens = tokens.sub(saleBalance);
            
            //no of tokens the buyer should have bought = saleBalance*100/(100+bonusPercentage)
            uint tokensForRefund = remainingTokens.mul(100).div(100 + bonusPercentage); //amount of tokens that should be excluded from the purchase;
            
            refund = tokensForRefund.div(rate); //processing the refund amount of the tokensForRefund;
            cost = cost.sub(refund);
            tokens = saleBalance;
        }
        
        totalWeiraised = totalWeiraised.add(cost);
        investments[buyer] = investments[buyer].add(cost);
        
        payable(saleWallet).transfer(cost);
        
        if(refund > 0)
        {
            payable(msg.sender).transfer(refund);
        }
        
        tokenContract.transferFrom(saleWallet,buyer, tokens);
        
        emit TokensPurchased(buyer, cost, tokens, refund);
    }
    
    function endSale() external onlyOwner {
        require(block.timestamp > endTime, "Sale time is not up yet");
        isSaleOn = false;
        saleEnded = true;
        
        emit SaleEnded();
    }
}