
const Escrow = artifacts.require("Escrow");
const Tokens = artifacts.require("Tokens");

module.exports = async (deployer, network) => {

  // Deploy Tokens
  await deployer.deploy(Tokens);
  //console.log("Tokens.address", Tokens.address);

  // Deploy Escrow
  await deployer.deploy(Escrow, Tokens.address);
  //console.log("Escrow.address", Escrow.address);

  return;
};