pragma solidity ^0.4.11;

import './SLMToken.sol';
import './math/SafeMath.sol';
import './lifecycle/Pausable.sol';
import './TokenVesting.sol';

/**

 * Copyright 2017 Sunny Look Media LLC (SLM)
 * -----------------------------------------
 * We have used OpenZepplin with some adjustments for this project.
 
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), 
 * to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 * and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 * @title SLMICO
 * -------------
 * @dev SLMICO is a base contract for managing a token crowdsale.
 * The SLMICO has a start and end timestamp, where investors can make
 * token purchases. The crowdsale will assign them tokens based
 * on a token per ETH rate. The Funds collected are forwarded to a wallet
 * as they arrive.
 *
 * Timeline/Changes
 * ----------------
 * 15.09.2017 transferred from private to public project
 */
 
 
contract SLMICO is Pausable{
  using SafeMath for uint256;

  //Gas/GWei
  uint public minContribAmount = 0.01 ether;
  uint public maxGasPrice = 50000000000;

  // The token being sold
  SLMToken public token;

  // The vesting contract
  TokenVesting public vesting;

  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // need to be enabled to allow investor to participate in the ico
  bool public icoEnabled;

  // address where funds are collected
  address public multisignWallet;

  // amount of raised money in wei
  uint256 public weiRaised;

  // totalSupply
  uint256 constant public totalSupply = 100000000 * (10 ** 18);
  //pre sale cap
  uint256 constant public preSaleCap = 10000000 * (10 ** 18);
  //sale cap
  uint256 constant public initialICOCap = 60000000 * (10 ** 18);
  //founder share
  uint256 constant public tokensForFounder = 10000000 * (10 ** 18);
  //dev team share
  uint256 constant public tokensForDevteam = 10000000 * (10 ** 18);
  //Partners share
  uint256 constant public tokensForPartners = 5000000 * (10 ** 18);
  //Charity share
  uint256 constant public tokensForCharity = 3000000 * (10 ** 18);
  //Bounty share
  uint256 constant public tokensForBounty = 2000000 * (10 ** 18);
    
  //Sold presale tokens
  uint256 public soldPreSaleTokens; 
  uint256 public sentPreSaleTokens;

  //ICO tokens
  //Is calcluated as: initialICOCap + preSaleCap - soldPreSaleTokens
  uint256 public icoCap; 
  uint256 public icoSoldTokens; 
  bool public icoEnded;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */ 
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);


  function SLMICO(address _multisignWallet) {
    token = createTokenContract();
    //send all dao tokens to multiwallet
    uint256 tokensToDao = tokensForDevteam.add(tokensForPartners).add(tokensForBounty).add(tokensForCharity);
    multisignWallet = _multisignWallet;
    token.transfer(multisignWallet, tokensToDao);
  }

  function createVestingForFounder(address founderAddress) onlyOwner(){
    require(address(vesting) == address(0));
    vesting = createTokenVestingContract(address(token));
    // create vesting schema for founders, total token amount is divided in 4 periods of 6 months each
    vesting.createVestingByDurationAndSplits(founderAddress, tokensForFounder, now.add(1 days), 26 weeks, 4);
    //send tokens to vesting contracts
    token.transfer(address(vesting), tokensForFounder);
  }

  //
  // Token related operations
  //

  // creates the ERC20 token 
  function createTokenContract() internal returns (SLMToken) {
    return new SLMToken();
  }

  // creates the ERC20 token Vesting
  function createTokenVestingContract(address tokenAddress) internal returns (TokenVesting) {
    return new TokenVesting(tokenAddress);
  }


  // enable token tranferability
  function enableTokenTransferability() onlyOwner {
    require(token != address(0));
    token.unpause(); 
  }

  // disable token tranferability
  function disableTokenTransferability() onlyOwner {
    require(token != address(0));
    token.pause(); 
  }


  //
  // Presale related operations
  //

  // set total pre sale sold token
  // can not be changed once the ico is enabled
  // Ico cap is determined by SaleCap + PreSaleCap - soldPreSaleTokens 
  function setSoldPreSaleTokens(uint256 _soldPreSaleTokens) onlyOwner{
    require(!icoEnabled);
    require(_soldPreSaleTokens <= preSaleCap);
    soldPreSaleTokens = _soldPreSaleTokens;
  }

  // transfer pre sale tokend to investors
  // soldPreSaleTokens need to be set beforehand, and bigger than 0
  // the total amount to tranfered need to be less or equal to soldPreSaleTokens 
  function transferPreSaleTokens(uint256 tokens, address beneficiary) onlyOwner {
    require(soldPreSaleTokens > 0);
    uint256 newSentPreSaleTokens = sentPreSaleTokens.add(tokens);
    require(newSentPreSaleTokens <= soldPreSaleTokens);
    sentPreSaleTokens = newSentPreSaleTokens;
    token.transfer(beneficiary, tokens);
  }


  //
  // ICO related operations
  //

  // set multisign wallet
  function setMultisignWallet(address _multisignWallet) onlyOwner{
    // need to be set before the ico start
    require(!icoEnabled || now < startTime);
    require(_multisignWallet != address(0));
    multisignWallet = _multisignWallet;
  }

  // delegate vesting contract owner
  function delegateVestingContractOwner(address newOwner) onlyOwner{
    vesting.transferOwnership(newOwner);
  }

  // set contribution dates
  function setContributionDates(uint256 _startTime, uint256 _endTime) onlyOwner{
    require(!icoEnabled);
    require(_startTime >= now);
    require(_endTime >= _startTime);
    startTime = _startTime;
    endTime = _endTime;
  }

  // enable ICO, need to be true to actually start ico
  // multisign wallet need to be set, because once ico started, invested funds is transfered to this address
  // once ico is enabled, following parameters can not be changed anymore:
  // startTime, endTime, soldPreSaleTokens
  function enableICO() onlyOwner{
    require(startTime >= now);

    require(multisignWallet != address(0));
    icoEnabled = true;
    icoCap = initialICOCap.add(preSaleCap).sub(soldPreSaleTokens);
  }


  // fallback function can be used to buy tokens
  function () payable whenNotPaused {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) payable whenNotPaused {
    require(beneficiary != address(0));
    require(msg.value >= minContribAmount);
    require(validPurchase());

    uint256 weiAmount = msg.value;
    uint256 returnWeiAmount;

    // calculate token amount to be created
    uint rate = getRate();
    assert(rate > 0);
    uint256 tokens = weiAmount.mul(rate);

    uint256 newIcoSoldTokens = icoSoldTokens.add(tokens);

    if (newIcoSoldTokens > icoCap) {
        newIcoSoldTokens = icoCap;
        tokens = icoCap - icoSoldTokens;
        uint256 newWeiAmount = tokens.div(rate);
        returnWeiAmount = weiAmount.sub(newWeiAmount);
        weiAmount = newWeiAmount;
    }

    // update state
    weiRaised = weiRaised.add(weiAmount);

    token.transfer(beneficiary, tokens);
    icoSoldTokens = newIcoSoldTokens;
    if (returnWeiAmount > 0){
        msg.sender.transfer(returnWeiAmount);
    }

    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

    forwardFunds(weiAmount);
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds(uint256 weiAmount) internal {
    multisignWallet.transfer(weiAmount);
  }

  // unsold ico tokens transfer automatically in endIco
  //function transferUnsoldIcoTokens() onlyOwner {
  //  require(hasEnded());
  //  require(icoSoldTokens < icoCap);
  //  uint256 unsoldTokens = icoCap.sub(icoSoldTokens);
  //  token.transfer(multisignWallet, unsoldTokens);
  //}

  // @return true if the transaction can buy tokens
  function validPurchase() internal constant returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    bool icoTokensAvailable = icoSoldTokens < icoCap;
    return !icoEnded && icoEnabled && withinPeriod && nonZeroPurchase && icoTokensAvailable;
  }

  // end ico by owner, not really needed in normal situation
  function endIco() onlyOwner {
    require(!icoEnded);
    icoEnded = true;
    // send unsold tokens to multi-sign wallet
    uint256 unsoldTokens = icoCap.sub(icoSoldTokens);
    token.transfer(multisignWallet, unsoldTokens);
  }

  // @return true if crowdsale event has ended
  function hasEnded() public constant returns (bool) {
    return (icoEnded || icoSoldTokens >= icoCap || now > endTime);
  }


  function getRate() public constant returns(uint){
    require(now >= startTime);
    if (now < startTime.add(2 days)){
      // day 1, day 2
      return 420;
    }else if (now < startTime.add(4 days)){
      // day 3, day 4
      return 385;
    }else if (now < startTime.add(6 days)){
      // day 5, day 6
      return 359; 
    }else if (now < endTime){
      // no discount
      return 350;
    }
    return 0;
  }

  // drain all eth for owner in an emergency situation
  function drain() onlyOwner {
    owner.transfer(this.balance);
  }
}
