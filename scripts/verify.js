const { ethers, run } = require("hardhat");

async function verifyContracts() {

  signers = await ethers.getSigners();
        owner = signers[0];
        admin = signers[1];

  const data = {
    dstContract: "0x6311A87d109432706432A16c8DbE9cC429b04443",
    user: "0x88416CFB7B807667C3DBC47Ec0D80a19d77365de",
    inToken: "0x9572a88Ed9a1488a1bc96499f2Fc57173093c3Dc",
    outToken : "0x4ed8b18d2a0c56d24564af942e6c5f8455793071",
    nonce: "0",
    amount: "100000000000000000000",
    fee:"0",
    isWrapped: "0",
    srcId: "97",
    dstId: "11155111"
}

console.log(owner.address, "relayer");
//   const message = await ethers.utils.solidityKeccak256(["address", "address", "address", "uint256", "uint256", "uint256", "uint256", "uint256"], [data.dstContract, data.user, data.inToken, data.nonce, data.amount, data.fee, data.srcId, data.dstId])
//   console.log("signed message -----------------", message)
//   const messageHash = await ethers.utils.arrayify(message)
//   console.log("admin wallet--------------", relayer.address)
//   const sig = await admin.signMessage(messageHash);
//   console.log("user signature ---------", sig)

//   const spli = await ethers.utils.splitSignature(sig);
//   // console.log("match ----- ", messageHash, sig, await token.nonces(randomWallet.address))
// // ethers 6.7.0
//   console.log("signature -------- ", spli)

  const userOp = {
    sender: "0x08709db8f69101eab4221c2d0b49109389a17df9",
    nonce: 0,
    initCode: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F05125fbfb9cf000000000000000000000000f39Fd6e51aad88F6F4ce6aB8827279cffFb922660000000000000000000000000000000000000000000000000000000000000001",
    callData: "0x",
    callGasLimit: 10000000,
    verificationGasLimit: 10000000,
    preVerificationGas : 60000,
    maxFeePerGas : 20000000000,
    maxPriorityFeePerGas: 20000000000,
    paymasterAndData : "0x",
    signature: "0x9e1dcbcc71fefadcb7dd9b168217fe3d6ba5da3edb21585a2cd3bc47def9ac9f7671ba5b2ace50f2220374b0d25b8f6a6019c1001e7cc9a76263503220ef8bf21b"
}

const message = await ethers.solidityPackedKeccak256(["address", "uint256", "bytes32", "bytes32", "uint256", "uint256", "uint256", "uint256", "uint256", "bytes32"], [(userOp.sender), (userOp.nonce), ethers.keccak256((userOp.initCode)), ethers.keccak256((userOp.callData)), (userOp.callGasLimit), (userOp.verificationGasLimit),
  (userOp.preVerificationGas), (userOp.maxFeePerGas), (userOp.maxPriorityFeePerGas), ethers.keccak256((userOp.paymasterAndData))])

  console.log("signed message -----------------", message)
  const messageHash = await ethers.arrayify(message)
  // console.log("admin wallet--------------", relayer.address)
  const sig = await owner.signMessage(messageHash);
  console.log("user signature ---------", sig)

}

verifyContracts();
