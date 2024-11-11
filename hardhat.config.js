require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.26", //  compiler version
      },
      // more compiler versions can be added here if needed
    ],
    plugins: ["@nomiclabs/hardhat-ethers"],
  },
  networks: {
    hardhat: {
      chainId: 1337, // Local Hardhat Network
    },
    // Add configurations for other networks as needed
  },
};
