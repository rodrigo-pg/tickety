// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NFT is ERC721 {

    address public marketPlaceAddress;

    constructor(address marketAddress) ERC721("Tickets", "TYT") {
        marketPlaceAddress = marketAddress;
    }   

    function mintTicket(uint itemId, address seller, address buyer) external {
        require(msg.sender == marketPlaceAddress, "Not authorized to mint");
        _mint(seller, itemId);
        _setApprovalForAll(seller, marketPlaceAddress, true);
        _setApprovalForAll(buyer, marketPlaceAddress, true);
    }

}