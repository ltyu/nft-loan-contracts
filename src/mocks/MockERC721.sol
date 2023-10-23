// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract PunkNFT is ERC721{
    constructor(address userToMint) ERC721("Punk", "PNK") {
        _mint(userToMint, 1);
    }
}