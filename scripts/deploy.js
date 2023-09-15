const { ethers, upgrades } = require("hardhat");
const hre = require("hardhat");
function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
async function main() {

    signers = await ethers.getSigners();
        owner = signers[0];
        admin = signers[1];
        
        // FACTORY = await hre.ethers.getContractFactory("FTT");
        // factory = await FACTORY.deploy();
        // sleep(5000)
        // console.log("address --- ", owner, admin)

        // // factory = "0x7a3066544b16c1cb35ea86de188c4eb7bbe31df3"

        PROXY = await hre.ethers.getContractFactory("OwnedUpgradeabilityProxy");
        proxy = await PROXY.deploy();

        BRIDGE = await hre.ethers.getContractFactory("Bridge8");
        bridge = await BRIDGE.deploy();
        sleep(5000)

        // SAITAMA = await hre.ethers.getContractFactory("SAITAMA");
        // saitama = await SAITAMA.deploy(1000000000);
        // sleep(5000)

        console.log("address --- ", proxy.target, bridge.target)

}

main()


// const { ethers, upgrades } = require("hardhat");
// const hre = require("hardhat");
// function sleep(ms) {
//     return new Promise((resolve) => setTimeout(resolve, ms));
//   }
// async function main() {
//         Factory = await hre.ethers.getContractFactory("Factory");
//         factory = await Factory.deploy();
//         console.log("factory.target: ",factory.target);
//         sleep(5000)
        
//         Bridge = await hre.ethers.getContractFactory("SaitaBridge2");
//         bridge = await Bridge.deploy();  
//         console.log("bridge.target: ",bridge.target);
//         sleep(5000)

//         // SAITAMA = await hre.ethers.getContractFactory("SAITAMA");
//         // saitama = await SAITAMA.deploy(1000000000);
//         // console.log("saitama.target: ",saitama.target);
//         // sleep(5000)

//         Proxy1 = await ethers.getContractFactory("OwnedUpgradeabilityProxy");
//         proxy1 = await Proxy1.deploy();  
//         console.log("proxy1.target: ",proxy1.target);
//         sleep(5000)

//         // await proxy1.upgradeTo(bridge.target);
        
//         // bridge = bridge.attach(proxy1.target);
        
//         // await bridge.initialize("0x88416CFB7B807667C3DBC47Ec0D80a19d77365de",factory.target);

// }

// main()