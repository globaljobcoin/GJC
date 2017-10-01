pragma solidity ^0.4.11;

import './token/PausableToken.sol';

contract SLMToken is PausableToken {
  string constant public name = "SLM";
  string constant public symbol = "SLM";
  uint256 constant public decimals = 18;
  uint256 INITIAL_SUPPLY = 100000000 * (10**decimals);

  function SLMToken() {
    // Set untransferable by default to the token
    paused = true;
    // asign all tokens to the contract creator
    totalSupply = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
  }
}
