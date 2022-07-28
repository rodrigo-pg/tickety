// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Market.sol";

contract NFT is ERC721URIStorage {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address public marketPlaceAddress;

    constructor(address marketAddress) ERC721("TicketMarket", "TTM") {
        marketPlaceAddress = marketAddress;
    }   

    function createTickets(
        uint ticketQuantity,
        uint256 eventFinalTime,
        string memory eventName,
        string memory eventDescription,
        string memory eventImage,
        string memory eventBanner
    ) public returns (uint) {
        _tokenIds.increment();

        Market(marketPlaceAddress).createEvent(
          ticketQuantity, 
          eventFinalTime, 
          eventName, 
          eventDescription, 
          _tokenIds.current(),
          msg.sender,
          eventImage,
          eventBanner
        );

        for (uint256 index = 0; index < ticketQuantity; index++) {
            uint256 newItemId = _tokenIds.current();
            _mint(msg.sender, newItemId);
            _tokenIds.increment();
        }

        setApprovalForAll(marketPlaceAddress, true);
        return _tokenIds.current();
    }
}