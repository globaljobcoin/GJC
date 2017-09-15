pragma solidity ^0.4.11;

import './token/PausableToken.sol';

contract SLMToken is PausableToken {
  string public name = "TBD";
  string public symbol = "TBD";
  uint256 public decimals = 18;
  uint256 INITIAL_SUPPLY = 100000000 * (10**18);

  function SLMToken() {
    // Set untransferable by default to the token
    paused = true;
    // asign all tokens to the contract creator
    totalSupply = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
  }
}
