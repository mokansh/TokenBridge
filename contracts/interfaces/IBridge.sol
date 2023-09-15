// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

interface IBridge {
    
    function setMintableToken(address token, bool isMintable) external returns (address);

}