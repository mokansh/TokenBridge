// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

interface IFactory {
    
    function deploy(address token, address bridge) external returns (address);

    function tokenAddrToWrappedToken(address token) external view returns(address wrappedToken);

    function wrappedTokenToTokenAddr(address token) external view returns(address _token);
}