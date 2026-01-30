/** @type import('hardhat/config').HardhatUserConfig */

require("@nomicfoundation/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.20"
      },
      {
        version: "0.8.22"
      },
      {
        version: "0.8.24"
      }
    ]
  }
};
