var ico = artifacts.require("./SLMICO.sol");

module.exports = function(deployer) {
  deployer.deploy(ico, web3.eth.accounts[0]);
};
