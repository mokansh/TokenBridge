const { ethers, upgrades } = require("hardhat");
const hre = require("hardhat");

async function main() {

  signers = await ethers.getSigners();
  user = signers[0];
  // admin = signers[1];


  BRIDGE = await ethers.getContractFactory("Bridge8")
  bridge = await BRIDGE.attach("0x4AB90628F669e237CfA52aC983aaC2B587fDa3Bc")
  // const gas = await bridge.listToken(["0x7F04E01b380ee5e2f048eB081D1C775593e97447", 97], ["0x840fCF99dE21c08f8e808af7595A81875dDAaFb6", 11155111], false, {value: 850000000000000})
  
  // console.log(gas);
  // const data = ""
  // await bridge.listToken(["0x9A36F58E71762a23d4903C6eA18C501a04feB1e5", 11155111],["0x52e949e035eb85f5Bcb934B8ceb620103eAa5d96", 97], "false", {value: 850000000000000})
  // // await bridge.deployToken(1, data, "0xb11Da2d03060Ab14e32B8b1208Be5492646340e3", user.address)
  
  admin = ["0x542b21371F92e8dbA2B098176a30688D1FB99F08", "0x46C036cdDde47392734E1E9d1F355d7F048FE2d8", "0x0562B66a3090EC177374706B939A520084F42007", "0x19E7E376E7C213B7E7e7e46cc70A5dD086DAff2A", "0x7B1aFE2745533D852d6fD5A677F14c074210d896", "0x4036bBdF6C43b82bdE4eB7c4E0fF78dfdB20E779", "0xe239cdc5fbe977a8a141B72194D3CF8c41bC5BC6"]
  await bridge.depositTokens("0x840fCF99dE21c08f8e808af7595A81875dDAaFb6", 100000000000000000000000n)
  
  console.log(await bridge.owner(), user.address)

  //   await bridge.unlock(user.address, "0x04D77Ae999e479D44AcF18b3797D3A5F31B7f785", "0x0000000000000000000000000000000000000000", 90000000000000000000n, 10000000000000000000n, 0, false, 11155111, 97, signature.r, signature.s, signature.v, {value: 0})



}

main()