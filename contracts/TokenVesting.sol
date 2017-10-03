pragma solidity ^0.4.15;


import './token/ERC20Basic.sol';
import './ownership/Ownable.sol';
import './math/SafeMath.sol';


/**
 * @title TokenVesting
 */
contract TokenVesting is Ownable {
    using SafeMath for uint256;

    ERC20Basic token;
    // vesting

    mapping (address => uint) totalVestedAmount;

    struct Vesting {
        uint amount;
        uint vestingDate;
    }

    address[] accountKeys;
    mapping (address => Vesting[]) public vestingAccounts;

    // events
    event Vest(address indexed beneficiary, uint256 amount);
    event VestingCreated(address indexed beneficiary, uint256 amount, uint256 vestingDate);

    // modifiers here
    modifier tokenSet() {
        require(address(token) != address(0));
        _;
    }

   function TokenVesting(address token_address){
        token = ERC20Basic(token_address);
    }

    function setVestingToken(address token_address) onlyOwner {
        token = ERC20Basic(token_address);
    }

    function createVestingByDurationAndSplits(address user, uint total_amount, uint startDate, uint durationPerVesting, uint times) onlyOwner tokenSet {
        uint256 vestingDate = startDate;
        uint i;
        require(startDate > now);
        require(times > 0);
        require(durationPerVesting > 0);
        uint amount = total_amount.div(times);
        for (i = 0; i < times; i++) {
            vestingDate = vestingDate.add(durationPerVesting);
            if (vestingAccounts[user].length == 0){
                accountKeys.push(user);
            }
            vestingAccounts[user].push(Vesting(amount, vestingDate));
            VestingCreated(user, amount, vestingDate);
        }
    }

    function getVestingAmountByNow(address user) constant returns (uint){
        uint amount;
        uint i;
        for (i = 0; i < vestingAccounts[user].length; i++) {
            if (vestingAccounts[user][i].vestingDate < now) {
                amount = amount.add(vestingAccounts[user][i].amount);
            }
        }
        return amount;
    }

    function getAvailableVestingAmount(address user) constant returns (uint){
        uint amount;
        amount = getVestingAmountByNow(user);
        amount = amount.sub(totalVestedAmount[user]);
        return amount;
    }

    function getAccountKeys(uint256 page) constant returns (address[10]){
        address[10] memory accountList;
        uint256 i;
        for (i=0 + page * 10; i<10; i++){
            if (i < accountKeys.length){
                accountList[i - page * 10] = accountKeys[i];
            }
        }
        return accountList;
    }

    function vest() tokenSet {
        uint availableAmount = getAvailableVestingAmount(msg.sender);
        require(availableAmount > 0);
        totalVestedAmount[msg.sender] = totalVestedAmount[msg.sender].add(availableAmount);
        token.transfer(msg.sender, availableAmount);
        Vest(msg.sender, availableAmount);
    }
    // drain all eth for owner in an emergency situation
    function drain() onlyOwner {
        owner.transfer(this.balance);
        token.transfer(owner, this.balance);
    }
}
