// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IERC20.sol";

contract Bridge8 is OwnableUpgradeable, ReentrancyGuardUpgradeable {

    uint256 public listingFee;
    address public factory;
    address public tokenFeeCollector;
    address public listingFeeCollector;
    address[] public admin;

    struct tokenInfo {
        address token;
        uint256 chain;
    }

    mapping(address => uint256) public inNonce;

    mapping(address => uint256) public feesForToken;
    mapping(uint256 => bool) public chainSupported;
    mapping(address => bool) public isBase;
    mapping(address => bool) public isWrapped;
    mapping(address => address) public tokenToToken;
    mapping(address => mapping(address => bool)) public isMintable;
    mapping(address => mapping(uint256 => bool)) public nonceProcessed;
    mapping(address => bool) public excludeFeeFromListing;
    mapping(address => uint256) public tokenChainId;
    mapping(address => mapping(address => address)) public tokenOwner;
    mapping(address => mapping(address => uint256)) public tokenDeposited;
    mapping(address => mapping(address => uint256)) public tokenWithdrawn;

    event Locked(address indexed user, address indexed inToken, address indexed outToken, uint256 amount, uint256 feeAmount, uint256 _nonce, uint256 isWrapped, uint256 srcId, uint256 dstId);
    event UnLocked(address indexed user, address indexed outToken, uint256 amount, uint256 feeAmount, uint256 _nonce, uint256 srcId, uint256 dstId);
    event TokenListed(address indexed baseToken, uint256 baseTokenChain, address indexed correspondingToken, uint256 correspondingTokenChain, bool isMintable, address indexed user);
    event TokenDelisted(address indexed baseToken, uint256 baseTokenChain, address indexed correspondingToken, uint256 correspondingTokenChain);
    event TokenDeposited(address indexed user, uint256 amount);
    event TokenWithdrawn(address indexed user, address indexed receiver, uint256 amount);
    event SignersChanged(address[] indexed newSigners);
    event ChainSupported(uint256 _chain, bool _supported);
    event FeeExcludedFromListing(address indexed user, bool ifExcluded);


    constructor() {
        _disableInitializers();
    }

    function initialize(address[] memory _admin, uint256 _listingFee, address _tokenFeeCollector, address _listingFeeCollector) external initializer {
        require(admin.length >= 3, "MINIMUM_SIGNERS_SHOULD_BE_3");
        require(_listingFee > 0, "LISTING_FEE_CANT_BE_ZERO");
        require(tokenFeeCollector != address(0) && listingFeeCollector != address(0), "CANT_PROVIDE_ZERO_ADDRESS");
        __Ownable_init();
        __ReentrancyGuard_init();
        admin = _admin;
        listingFee = _listingFee;
        tokenFeeCollector = _tokenFeeCollector;
        listingFeeCollector = _listingFeeCollector;

    }

    /** 
     * @dev cannot receive eth directly
     */
    receive() external payable {
        revert("DIRECT_ETH_TRANSFER_NOT_SUPPORTED");
    }

     /** 
     * @dev cannot receive eth directly
     */
    fallback() external payable {
        revert("DIRECT_ETH_TRANSFER_NOT_SUPPORTED");
    }

    /**
     * @dev Lock the `_amount` of `inTokens` in the bridge contract for `dstId` chain.
     * @param inToken locking token address
     * @param _amount amount of token to lock
     * @param dstId destination chain on which user will claim token
     * Emits a {Locked} event.
     */
    function lock(address inToken, uint256 _amount, uint256 dstId) external payable nonReentrant {
        require(_amount > 0, "AMOUNT_CANT_BE_ZERO");    
        require(inToken != address(0), "TOKEN_ADDRESS_CANT_BE_NULL");
        require(inToken.code.length > 0, "TOKEN_NOT_ON_THIS_CHAIN");
        address outToken = tokenToToken[inToken];
        require(outToken != address(0), "UNSUPPORTED_TOKEN");
        
        require(chainSupported[dstId], "INVALID_CHAIN");

        uint256 srcId;
        assembly {
            srcId := chainid()
        }
        require(tokenChainId[inToken] == srcId, "UNSUPPORTED_TOKEN");

        uint256 _isWrapped;

        if(isWrapped[inToken]) _isWrapped = 1;
        else _isWrapped = 0;
        
        address _user = msg.sender;
        uint256 tokenAmount;
        uint256 fee = feesForToken[inToken];
        uint256 feesAmount;
        

        if(_isWrapped == 0) {
                
                (tokenAmount, feesAmount) = transferAndCalcAmountAndFees(inToken, _user, _amount, fee);

                emit Locked(_user, inToken, outToken, tokenAmount, feesAmount, inNonce[_user]++, _isWrapped, srcId, dstId);

        } else if(_isWrapped == 1) {

                (tokenAmount, feesAmount) = transferAndCalcAmountAndFees(inToken, _user, _amount, fee);

                burn(inToken, tokenAmount+feesAmount);

                emit Locked(_user, inToken, outToken, tokenAmount, feesAmount, inNonce[_user]++, _isWrapped, srcId, dstId);
            
        }

    }

    /**
     * @dev Unlock the `amount` of tokens corresponding to `inToken`
     * @param inToken locked token address
     * @param amount amount of token to unlock
     * @param feeAmount fee on locked amount on source chain
     * @param _nonce user lock nonce on source chain
     * @param _isWrapped 1 if inToken is mintable otherwise 0
     * @param srcId source chain on which user has locked token
     * @param r[] r part of the signature of the signers
     * @param s[] s part of the signature of the signers
     * @param v[] v part of the signature of the signers
     * Emits a {unLocked} event.
     */
    function unlock(address inToken, uint256 amount, uint256 feeAmount, uint256 _nonce, uint256 _isWrapped, uint256 srcId, bytes32[] memory r, bytes32[] memory s, uint8[] memory v) external payable nonReentrant {
        address user = msg.sender;
        require(inToken != address(0), "TOKEN_ADDRESS_CANT_BE_NULL");
        require(user != address(0), "INVALID_RECEIVER");
        require(amount > 0, "AMOUNT_CANT_BE_ZERO");

        address outToken = tokenToToken[inToken];
        require(outToken != address(0), "UNSUPPORTED_TOKEN");

        require(chainSupported[srcId], "INVALID_CHAIN");


        require(!nonceProcessed[user][_nonce], "NONCE_ALREADY_PROCESSED");
        
        bool mintable = isMintable[inToken][outToken];

        uint256 dstId;
        assembly {
            dstId := chainid()
        }
        require(tokenChainId[outToken] == dstId, "CLAIM_TOKEN_NOT_BINDED_WITH_THIS_CHAIN");

        bool success = verify(address(this), user, inToken, outToken, _nonce, amount, feeAmount, _isWrapped, srcId, dstId, r, s, v);
        require(success, "INVALID_RECOVERED_SIGNER");

        // inToken is base token then isWrapped = 0
        // inToken is wrapped token then isWrapped = 1

        nonceProcessed[user][_nonce] = true;

        if(_isWrapped == 0) {

            if(mintable) {
                if(feeAmount > 0) mint(outToken, tokenFeeCollector, feeAmount);
                mint(outToken, user, amount);
            } else {
                if(feeAmount > 0) {
                    success = IERC20(outToken).transfer(tokenFeeCollector, feeAmount);
                    if(!success) revert("TOKEN_FEE_COLLECTION_FAILED");
                }
                success = IERC20(outToken).transfer(user, amount);
                if(!success) revert("TOKEN_TRANSFER_FAILED");
            }

            
        } else if(_isWrapped == 1) {

            if(feeAmount > 0) {
                success = IERC20(outToken).transfer(tokenFeeCollector, feeAmount);
                if(!success) revert("TOKEN_FEE_COLLECTION_FAILED");
            } 
            success = IERC20(outToken).transfer(user, amount);
            if(!success) revert("TOKEN_TRANSFER_FAILED");
        }

        emit UnLocked(user, outToken, amount,  feeAmount, _nonce, srcId, dstId);
    }


    /**
     * @dev internal function to call mint function of the token address
     */
    function mint(address token, address to, uint256 amount) internal {
        IERC20 _token = IERC20(payable(token));
        bytes memory init = returnHash(to, amount);
                if (init.length > 0)
                    
                    assembly 
                    {
                        if eq(call(gas(), _token, 0, add(init, 0x20), mload(init), 0, 0), 0) {
                            revert(0, 0)
                        }
                    }
    }

    /**
     * @dev internal function to call burn function of the token address
     */
    function burn(address token, uint256 amount) internal {
        IERC20 _token = IERC20(payable(token));
        bytes memory init = returnHash(amount);
                if (init.length > 0)
                    
                    assembly 
                    {
                        if eq(call(gas(), _token, 0, add(init, 0x20), mload(init), 0, 0), 0) {
                            revert(0, 0)
                        }
                    }
    }
    /**
     * @dev function to calculate the fees amount and transfer token from user to this contract
     */
    function transferAndCalcAmountAndFees(address token, address _user, uint256 amount, uint256 fee) private returns(uint256 tokenAmount, uint256 feeAmount) {

                uint256 beforeAmount = (IERC20(token).balanceOf(address(this)));
                bool success = IERC20(token).transferFrom(_user, address(this), amount);
                if(!success) revert("TRANSFER_FAILED_WHILE_LOCKING");
                tokenAmount = (IERC20(token).balanceOf(address(this))) - beforeAmount;
            
                if(fee > 0) {
                    feeAmount = tokenAmount * fee / 10000;
                    tokenAmount -= feeAmount;
                }
    }

    /**
     * @dev function to verify the authenticity of the signatures provided in form of r[], s[] and v[] 
     */

    function verify(address dstContract, address user, address inToken, address outToken, uint256 nonce, uint256 amount, uint256 feeAmount, uint256 _isWrapped, uint256 srcId, uint256 dstId, bytes32[] memory sigR, bytes32[] memory sigS, uint8[] memory sigV) internal view returns (bool) {
        uint256 len = admin.length;
        require(sigR.length == len && sigS.length == len && sigV.length == len, "INVALID_NUMBER_OF_SIGNERS");
        for(uint i=0; i<len; ++i) {
            bytes32 hash = prefixed(keccak256(abi.encodePacked(dstContract, user, inToken, outToken, nonce, amount, feeAmount, _isWrapped, srcId, dstId)));
            address signer = ecrecover(hash, sigV[i], sigR[i], sigS[i]);
            require(signer != address(0), "INVALID_SIGNATURE");
            require(admin[i] == signer, "INVALID_VALIDATOR");
        }
        return true;
    }
    /**
     * @dev making hash EIP-191 compatible
     */
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev returning the encoded mint function to call
     */
    function returnHash(address to, uint256 amount) internal pure returns(bytes memory data) {
        data = abi.encodeWithSignature("mint(address,uint256)", to, amount);
    }

    /**
     * @dev returning the encoded mint function to call
     */
    function returnHash(uint256 amount) internal pure returns(bytes memory data) {
        data = abi.encodeWithSignature("burn(uint256)", amount);
    }

    /**
     * @dev token owner can list the pair of their token with their corresponding chain id
     * @param baseToken struct that contains token address and its corresponding chain id
     * @param correspondingToken struct that contains token address and its corresponding chain id
     * @param _isMintable if corresponding token address is mintable then its `true` otherwise `false`
     */
    function listToken(tokenInfo memory baseToken, tokenInfo memory correspondingToken, bool _isMintable) external payable {
        require(baseToken.token != address(0), "INVALID_ADDR");
        require(correspondingToken.token != address(0), "INVALID_ADDR");
        require(tokenToToken[baseToken.token] == address(0) && tokenToToken[correspondingToken.token] == address(0), "THIS_PAIR_ALREADY_LISTED");

        isMintable[baseToken.token][correspondingToken.token] = _isMintable;
        isMintable[correspondingToken.token][baseToken.token] = _isMintable;
        tokenToToken[baseToken.token] = correspondingToken.token;
        tokenToToken[correspondingToken.token] = baseToken.token;
        isBase[baseToken.token] = true;
        if(_isMintable) isWrapped[correspondingToken.token] = true;
        else isWrapped[correspondingToken.token] = false;

        tokenChainId[baseToken.token] = baseToken.chain;
        tokenChainId[correspondingToken.token] = correspondingToken.chain;

        tokenOwner[baseToken.token][correspondingToken.token] = msg.sender;
        tokenOwner[correspondingToken.token][baseToken.token] = msg.sender;

        if(!excludeFeeFromListing[msg.sender]) transferListingFee(listingFeeCollector, msg.sender, listingFee);

        emit TokenListed(baseToken.token, baseToken.chain, correspondingToken.token, correspondingToken.chain, _isMintable, msg.sender);

    }

    /**
     * @dev platform owner can delist the pair of the token
     * @param baseToken struct that contains token address and its corresponding chain id
     * @param correspondingToken struct that contains token address and its corresponding chain id
     */
    function delistTokenByOwner(tokenInfo memory baseToken, tokenInfo memory correspondingToken) external onlyOwner {
        require(baseToken.token != address(0), "INVALID_ADDR");
        require(correspondingToken.token != address(0), "INVALID_ADDR");
        require(tokenToToken[baseToken.token] != address(0) && tokenToToken[correspondingToken.token] != address(0), "ALREADY_DELISTED");

        delete tokenToToken[baseToken.token];
        delete tokenToToken[correspondingToken.token];

        tokenChainId[baseToken.token] = 0;
        tokenChainId[correspondingToken.token] = 0;

        emit TokenDelisted(baseToken.token, baseToken.chain, correspondingToken.token, correspondingToken.chain);
    }

    /**
     * @dev token lister can delist the pair of the token
     * @param baseToken struct that contains token address and its corresponding chain id
     * @param correspondingToken struct that contains token address and its corresponding chain id
     */
    function delistTokenByUser(tokenInfo memory baseToken, tokenInfo memory correspondingToken) external {
        require(tokenOwner[baseToken.token][correspondingToken.token] == msg.sender, "NOT_TOKEN_OWNER");
        require(tokenToToken[baseToken.token] != address(0) && tokenToToken[correspondingToken.token] != address(0), "ALREADY_DELISTED");

        require(baseToken.token != address(0), "INVALID_ADDR");
        require(correspondingToken.token != address(0), "INVALID_ADDR");

        delete tokenToToken[baseToken.token];
        delete tokenToToken[correspondingToken.token];

        tokenChainId[baseToken.token] = 0;
        tokenChainId[correspondingToken.token] = 0;

        emit TokenDelisted(baseToken.token, baseToken.chain, correspondingToken.token, correspondingToken.chain);
    }

    /**
     * @dev take the listing fee while listing token
     */
    function transferListingFee(address to, address _user,  uint256 _value) private nonReentrant {
        require(to != address(0), "CANT_SEND_TO_NULL_ADDRESS");
        require(_value >= listingFee, "INCREASE_LISTING_FEE");
        (bool success, ) = payable(to).call{value:listingFee}("");
        require(success, "LISTING_FEE_TRANSFER_FAILED");
        uint256 remainingEth = _value - listingFee;
        if (remainingEth > 0) {
            (success,) = payable(_user).call{value: remainingEth}("");
            require(success, "REFUND_REMAINING_ETHER_SENT_FAILED");
        }
    }


    /**
    * @dev owner can change the listing fee
    */
    function setListingFee(uint256 newFee) external onlyOwner {
        require(newFee != listingFee, "SAME_FEE_PROVIDED");
        require(newFee >= 0, "INVALID_FEE");
        listingFee = newFee;
    }

    /**
    * @dev owner can change the listing fee collector address
    */
    function setListingFeeCollector(address collector) external onlyOwner {
        require(collector != address(0), "CANT_BE_NULL_ADDRESS");
        listingFeeCollector = collector;

    }

    /**
    * @dev owner can exclude particular address to give the listing fee while listing token
    */
    function setExcludeFeeFromListing(address user, bool ifExcluded) external onlyOwner {
        require(user != address(0), "CANT_BE_NULL_ADDRESS");
        excludeFeeFromListing[user] = ifExcluded;

        emit FeeExcludedFromListing(user, ifExcluded);
    }

    /**
    * @dev owner can change the signer addresses 
    */
    function changeAdmin(address[] memory newAdmin) external onlyOwner {
        require(newAdmin.length >= 3, "VALIDATORS_ARE_LESS_THAN_3");
        admin = newAdmin;

        emit SignersChanged(newAdmin);
    }

    /**
    * @dev owner can set fee for particular token for bridging 
    */
    function setFeeForToken(address token, uint256 fee) external onlyOwner {
        require(token != address(0), "INVALID_TOKEN");
        require(fee < 10000, "FEE_CANT_BE_100%");
        feesForToken[token] = fee;
    }

    /**
    * @dev owner can set if particular chain is supported or not 
    */
    function setChainSupported(uint256 chainId, bool supported) external onlyOwner {
        require(chainId != 0, "INVALID_CHAIN_ID");
        chainSupported[chainId] = supported;
        emit ChainSupported(chainId, supported);
    }

     /**
    * @dev owner can change the token fee collector address
    */
    function setFeeCollector(address collector) external onlyOwner {
        require(collector != address(0), "INVALID_OWNER");
        tokenFeeCollector = collector;
    }

     /**
    * @dev returns total number of signers that are verified while unlocking the tokens 
    */
    function getTotalSigners() external view returns(uint256) {
        return admin.length;
    }

    /**
    * @dev token lister has to deposit tokens if none of the listed token are mintable or burnable
    * @param token token address to deposit in bridge contract 
    * @param amount amount of tokens to deposit in bridge contract
    */
    function depositTokens(address token, uint256 amount) external {
        require(token.code.length > 0, "TOKEN_NOT_DEPLOYED_ON_THIS_CHAIN");
        address _correspondingToken = tokenToToken[token];
        require(_correspondingToken != address(0), "TOKEN_NOT_LISTED");
        require(amount > 0, "AMOUNT_CANT_BE_ZERO");
        address user = msg.sender;
        require(tokenOwner[token][_correspondingToken] == user, "ONLY_TOKEN_LISTER_CAN_DEPOSIT");

        uint256 beforeBal = IERC20(token).balanceOf(address(this));
        IERC20(token).transferFrom(user, address(this), amount);
        uint256 actualBal = IERC20(token).balanceOf(address(this)) - beforeBal;

        tokenDeposited[token][user] += actualBal;

        emit TokenDeposited(user, actualBal);
    }

    /**
    * @dev token lister can withdraw tokens 
    * @param token token address to withdraw from bridge contract 
    * @param receiver address to recive the withdrawn tokens
    * @param amount amount of tokens to deposit in bridge contract
    */
    function withdrawTokens(address token, address receiver, uint256 amount) external {
        require(token.code.length > 0, "TOKEN_NOT_DEPLOYED_ON_THIS_CHAIN");
        address _correspondingToken = tokenToToken[token];
        require(_correspondingToken != address(0), "TOKEN_NOT_LISTED");
        require(amount > 0, "AMOUNT_CANT_BE_ZERO");
        address user = msg.sender;

        require(tokenOwner[token][_correspondingToken] == user, "ONLY_TOKEN_LISTER_CAN_WITHDRAW");
        require(amount <= IERC20(token).balanceOf(address(this)), "CANT_WITHDRAW_MORE_THAN_AVAILABLE");

        if(isWrapped[token]) revert("CANT_WITHDRAW_WRAPPED_TOKENS");

        tokenWithdrawn[token][user] += amount;
        IERC20(token).transfer(receiver, amount);

        emit TokenWithdrawn(user, receiver, amount);
    }

    /**
    * @dev token lister can change their ownership of listing tokens
    * @param token token address to change its lister owner
    * @param newOwner new owner address
    */
    function changeTokenLister(address token, address newOwner) external {
        require(token.code.length > 0, "TOKEN_NOT_DEPLOYED_ON_THIS_CHAIN");
        require(newOwner != address(0), "NEW_OWNER_CANT_BE_NULL");
        address _correspondingToken = tokenToToken[token];
        require(_correspondingToken != address(0), "TOKEN_NOT_LISTED");
        require(tokenOwner[token][_correspondingToken] == msg.sender, "ONLY_TOKEN_LISTER_CAN_CHANGE");

        tokenOwner[token][_correspondingToken] = newOwner;
        tokenOwner[_correspondingToken][token] = newOwner;

    }

    /**
    * @dev returns the addresses of signers
    */
    function getSigners() external view returns(address[] memory ) {
        return admin;
    }
    
}