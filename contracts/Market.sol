// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Market is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;

    enum ListingStatus {
	    Active,
	    Sold,
	    Cancelled
	  }

    struct MarketItem {
      uint itemId;
      address nftContract;
      uint256 tokenId;
      address payable org;
      address payable seller;
      address payable owner;
      uint256 price;
      uint256 eventFinalTime;
      bool used;
      ListingStatus status;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => address) private ticketsByEventCreators;

    function createTicketMarket(
    address nftContract,
    uint256 price,
    uint256 initialTicketId,
    uint256 finalTickedId,
    uint256 eventFinalTime
    ) public payable nonReentrant {
      require(price > 0, "Price must be at least 1 wei");

      for (initialTicketId; initialTicketId <= finalTickedId; initialTicketId++) {
          require(ticketsByEventCreators[initialTicketId] == address(0), "Not event creator"); 

          _itemIds.increment();
          uint256 itemId = _itemIds.current();

          idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            initialTicketId,
            payable(msg.sender),
            payable(msg.sender),
            payable(address(0)),
            price,
            eventFinalTime,
            false,
            ListingStatus.Active
          );

          ticketsByEventCreators[initialTicketId] = msg.sender;

          IERC721(nftContract).transferFrom(msg.sender, address(this), initialTicketId);
      }
    }

    function cancelTicketMarket(uint256 initialItemId, uint256 finalItemId) public nonReentrant {
      for (initialItemId; initialItemId <= finalItemId; initialItemId++) {
        MarketItem storage item = idToMarketItem[initialItemId];

		    require(msg.sender == item.seller, "Only seller can cancel listing");
		    require(item.status == ListingStatus.Active, "Listing is not active");

		    item.status = ListingStatus.Cancelled;

		    IERC721(item.nftContract).transferFrom(address(this), msg.sender, item.tokenId);
      }
	  }

    function buyTicket(
    address nftContract,
    uint256 itemId
    ) public payable nonReentrant {
      uint price = idToMarketItem[itemId].price;
      uint tokenId = idToMarketItem[itemId].tokenId;

      require(msg.sender != idToMarketItem[itemId].seller, "Seller cannot be buyer");
      require(msg.value >= price, "Insufficient payment");
      require(idToMarketItem[itemId].status == ListingStatus.Active, "Listing is not active");
      require(block.timestamp < idToMarketItem[itemId].eventFinalTime, "Event finished");
      require(idToMarketItem[itemId].used == false, "Ticket already used");

      idToMarketItem[itemId].owner = payable(msg.sender);
      idToMarketItem[itemId].status = ListingStatus.Sold;

      payable(owner()).transfer(msg.value / 100);
      
      if (idToMarketItem[itemId].seller != idToMarketItem[itemId].org) {
        idToMarketItem[itemId].org.transfer(msg.value / 100);
        idToMarketItem[itemId].seller.transfer(msg.value - (msg.value / 50));
      } else {
        idToMarketItem[itemId].seller.transfer(msg.value - (msg.value / 100));
      }

      IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
    } 

    function resellTicket(uint256 price, uint256 itemId) public {
      bool isUsed = idToMarketItem[itemId].used;

      require(isUsed == false, "Ticket already used");
      require(idToMarketItem[itemId].owner == msg.sender, "Not owner of ticket");
      require(block.timestamp < idToMarketItem[itemId].eventFinalTime, "Event finished");

      idToMarketItem[itemId] = MarketItem(
        itemId,
        idToMarketItem[itemId].nftContract,
        idToMarketItem[itemId].tokenId,
        idToMarketItem[itemId].org,
        payable(msg.sender),
        payable(address(0)),
        price,
        idToMarketItem[itemId].eventFinalTime,
        false,
        ListingStatus.Active
      );

      IERC721(idToMarketItem[itemId].nftContract).transferFrom(msg.sender, address(this), idToMarketItem[itemId].tokenId);  
    }

    function useTicket(uint256 itemId) external {
      address org = idToMarketItem[itemId].org;
      address owner = idToMarketItem[itemId].owner;
      bool isUsed = idToMarketItem[itemId].used;

      require(owner != address(0), "Ticket not bought yet");
      require(msg.sender == org || msg.sender == owner, "Not allowed to use ticket");
      require(isUsed == false, "Ticket already used");
      require(block.timestamp < idToMarketItem[itemId].eventFinalTime, "Event finished");

      idToMarketItem[itemId].used = true;
    }
}