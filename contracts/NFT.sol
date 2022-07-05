// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFT is ERC721URIStorage {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address public marketPlaceAddress;

    constructor(address marketAddress) ERC721("TicketMarket", "TTM") {
        marketPlaceAddress = marketAddress;
    }   

    function createTickets(string memory tokenURI, uint ticketQuantity) public {
        for (uint256 index = 0; index < ticketQuantity; index++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();
            _mint(msg.sender, newItemId);
            _setTokenURI(newItemId, tokenURI);
        }
        setApprovalForAll(marketPlaceAddress, true);
    }
    
}