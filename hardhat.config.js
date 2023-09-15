
require("@nomicfoundation/hardhat-toolbox");
// require('@openzeppelin/hardhat-upgrades');
// require("@nomiclabs/hardhat-etherscan");

require("dotenv").config();

const privateKeyOwner = process.env.ACCOUNT_OWNER_PVT_KEY;
const privateKeyA = process.env.ACCOUNT_A_PVT_KEY;
// const privateKeyB = process.env.ACCOUNT_B_PVT_KEY;


// const etherscanAPIkey = process.env.ETHERSCAN_API_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.18",
  settings:{
    optimizer: {
      enabled: true,
      runs: 200,
    },
    viaIR: true
  },
},
networks : {
  sepolia: {
        url: "https://sepolia.infura.io/v3/e42985dd7f0f467d9218c01fa4757c07",
        // chainId: 97,
        // gasPrice: 20000000000,
        accounts : [privateKeyOwner, privateKeyA]
      },

      bscTestnet: {
        url: "https://data-seed-prebsc-1-s3.binance.org:8545/",
        // chainId: 97,
        // gasPrice: 20000000000,
        accounts : [privateKeyOwner, privateKeyA]
      },

mainnet: {
  url: process.env.ETH_RPC || "",
  // accounts: [`0x384158242f384bcbb27cbb663fbca37e`]
  accounts: [`0x${process.env.PVT_KEY}`]
},
bsc: {
  url: process.env.BSC_RPC || "",
  // accounts: [`0x384158242f384bcbb27cbb663fbca37e`]
  // accounts: [`0x${process.env.PVT_KEY}`]
},
// hardhat:{
//   allowUnlimitedContractSize: true
// }

},
etherscan: {
  apiKey: process.env.ETHERSCAN_API_KEY,
    // bsc: process.env.BSC_API_KEY,
    // bscTestnet: 'FUFZFC8P2PFBBTDN3EZ3288I3MPE8M37SY',

},
contractSizer: {
  alphaSort: true,
  disambiguatePaths: false,
  runOnCompile: true,
  strict: true,
}
};

// https://ethereum-sepolia.blockpi.network/v1/rpc/5da0756c67b826416c555a327f1070c0a74ab60e