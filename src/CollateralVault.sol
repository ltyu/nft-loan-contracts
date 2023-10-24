// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract CollateralVault is EIP712 {
    // The address of the borrower
    address immutable borrower;

    // EIP712 Type hash used to validate signature
    bytes32 private constant TYPE_HASH = keccak256("Repay(address receiver)");

    // The NFT that is being locked
    ERC721 public immutable acceptedNFT;
    // NFT ID
    uint256 public tokenId;

    // Minimum collateral ratio before the collateral is liquidatable
    // @dev for now it's hardcoded to 1
    uint256 public minimumCollateralRatio = 1 ether;

    // Price of the NFT. Typically this is determined through an Oracle
    uint256 public price = 100 ether;

    // Total stable amount borrowed
    uint256 amountBorrowed;

    // The stable asset loaned out
    ERC20 public immutable stableToken;

    // TODO add Nonce to prevent replay attack

    error NotEnoughCollateral();
    error NotEnoughStableLeft();
    error AlreadyDeposited();
    error InvalidReceiver();
    error NotBorrower();

    modifier onlyBorrower {
        if (msg.sender != borrower)
            revert NotBorrower();
        _;
    }
    constructor(address _acceptedNFT, address _stableToken, address _borrower) EIP712("CollateralVault", "1"){
        acceptedNFT = ERC721(_acceptedNFT);
        stableToken = ERC20(_stableToken);
        borrower = _borrower;
    }

    /**
     * Deposits the NFT from the msg.sender
     * @param _tokenId tokenId of NFT to deposit
     */
    function depositNFT(uint256 _tokenId) external onlyBorrower {
        if (acceptedNFT.balanceOf(address(this)) > 0 )
            revert AlreadyDeposited();
        tokenId = _tokenId;

        acceptedNFT.transferFrom(msg.sender, address(this), tokenId);
    }

    /**
     * Borrows up to the price of collateral
     * @param amount amount to borrow
     */
    function borrow(uint256 amount) external onlyBorrower {
        uint256 newAmount = amountBorrowed + amount;
        if (acceptedNFT.balanceOf(address(this)) == 0 || newAmount > price)
            revert NotEnoughCollateral();
        if (amount > stableToken.balanceOf(address(this)))
            revert NotEnoughStableLeft();

        stableToken.transfer(msg.sender, amount);
        amountBorrowed += amount;
        
    }
    /**
     * Repays the loan using ERC712, and returns NFT to receiver
     * @param receiver address to return the NFT, and debit the stable from
     * @param v used for ercrecover
     * @param r used for ercrecover
     * @param s used for ercrecover
     * @dev it is expected that the user has approved this contract to transfer the stable
     */    
    function repayPermit(
        address receiver,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (address recoveredReceiver){
        recoveredReceiver = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(TYPE_HASH, receiver))),
            v,
            r,
            s
        );
        if (recoveredReceiver != receiver)
            revert InvalidReceiver();

        // Calculate the amount to bring the user above MCR
        uint256 amount = 1 ether;

        // Transfer stable from borrower 
        stableToken.transferFrom(recoveredReceiver, address(this), amount);

        // Return NFT
        acceptedNFT.safeTransferFrom(address(this), receiver, tokenId);
    }

    /**
     * Sets a new price
     * @param _price new price of the nft
     * @dev typically this is updated by an oracle. But for PoC, we'll manually do it.
     */
    function setPrice(uint256 _price) external {
        price = _price;
    }

    function repay() external {
        // @dev normal repay function
    }

    // returns the collateral is liquidatable
    function isLiquidatable() public view returns (bool) {
        return getCollateralRatio() < minimumCollateralRatio;
    }

    // returns the collateral ratio of the NFT
    function getCollateralRatio() internal view returns (uint256) {
        return price * 1 ether / amountBorrowed;
    }
}
