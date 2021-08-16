//SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Token is ERC20, Ownable {
    
     using SafeMath for uint256;
    
    constructor() ERC20("Token", "TKN") {
        
        // _mint(msg.sender,20000000000 * (10**18));//reserve 
        // _mint(msg.sender,10000000000 * (10**18));//Interest Payout Wallet
        // _mint(msg.sender,5000000000 * (10**18));//Team Members HR Wallet
        // _mint(msg.sender,6500000000 * (10**18));//Company General Fund Wallet
        // _mint(msg.sender,1000000000 * (10**18));//Bounties/Airdrops Wallet
        // _mint(msg.sender,12500000000 * (10**18));//Token Sale Wallet
        
        _mint(address(this), 55000000000 * (10**18) );
        transfer(0xc5625D68C341E336aC0096D10a0bE52D68e7011b,20000000000 * (10**18));//reserve 
        transfer(0xc5625D68C341E336aC0096D10a0bE52D68e7011b,10000000000 * (10**18));//Interest Payout Wallet
        transfer(0xc5625D68C341E336aC0096D10a0bE52D68e7011b,5000000000 * (10**18));//Team Members HR Wallet
        transfer(0xc5625D68C341E336aC0096D10a0bE52D68e7011b,6500000000 * (10**18));//Company General Fund Wallet
        transfer(0xc5625D68C341E336aC0096D10a0bE52D68e7011b,1000000000 * (10**18));//Bounties/Airdrops Wallet
        transfer(0xc5625D68C341E336aC0096D10a0bE52D68e7011b,12500000000 * (10**18));//Token Sale Wallet
    }

}
