// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NFT.sol";

contract Market is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _eventIds;
    address private nftContract;

    enum ListingStatus {
	    Active,
	    Sold,
	    Cancelled
	  }

    enum EventListingStatus {
      Created,
      Listed,
      Cancelled
    }

    struct Event {
      uint eventId;
      string eventName;
      string eventDescription;
      address payable creator;
      uint256 eventFinalTime;
      uint256 ticketsQuantity;
      uint256 initialItemId;
      EventListingStatus status;
      string eventImage;
      string eventBanner;
    }

    struct MarketItem {
      uint itemId;
      uint eventId;
      address nftContract;
      uint256 tokenId;
      address payable seller;
      address payable owner;
      uint256 price;
      bool used;
      ListingStatus status;
    }

    //Cada evento deveria mapear para outro map de tokens
    mapping(uint256 => Event) private idToEvents;
    mapping(uint256 => MarketItem) private idToMarketItem;

    function setNftContract(address newNftContract) external onlyOwner {
      nftContract = newNftContract;
    }

    function createEvent(
        uint ticketQuantity,
        uint256 eventFinalTime,
        string memory eventName,
        string memory eventDescription,
        uint initialTokenId,
        address creator,
        string memory eventImage,
        string memory eventBanner
    ) external nonReentrant {
      require(msg.sender == nftContract, "Not authorized to create");
      _eventIds.increment();

      uint eventId = _eventIds.current();

      idToEvents[eventId] = Event(
          eventId,
          eventName,
          eventDescription,
          payable(creator),
          eventFinalTime,
          ticketQuantity,
          initialTokenId,
          EventListingStatus.Created,
          eventImage,
          eventBanner
      );
    }

    function createTicketMarket(
    uint eventId,
    uint256 price
    ) public payable nonReentrant {
      require(price > 0, "Price must be at least 1 wei");

      Event storage eventData = idToEvents[eventId];

      require(msg.sender == eventData.creator, "Not event creator");
      require(eventData.status != EventListingStatus.Listed, "Event already listed");
      require(block.timestamp < eventData.eventFinalTime, "Event already finished");

      uint initialTicketId = eventData.initialItemId;
      uint finalTickedId = initialTicketId + eventData.ticketsQuantity - 1;

      for (uint currentTokenId = initialTicketId; currentTokenId <= finalTickedId; currentTokenId++) {
          _itemIds.increment();
          uint256 itemId = _itemIds.current();

          idToMarketItem[itemId] = MarketItem(
            itemId,
            eventId,
            nftContract,
            currentTokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            false,
            ListingStatus.Active
          );

          IERC721(nftContract).transferFrom(msg.sender, address(this), currentTokenId);
      }

      eventData.status = EventListingStatus.Listed;
    }

    function cancelTicketMarket(uint eventId) public nonReentrant {
      bool hasBoughtTickets = false;
      Event storage eventData = idToEvents[eventId];

      require(eventData.status == EventListingStatus.Listed, "Event not listed");
      require(msg.sender == eventData.creator, "Not event creator");

      for (uint index = 1; index <= _itemIds.current(); index++) {
        MarketItem storage item = idToMarketItem[index];

        if (item.eventId == eventId && (item.seller != eventData.creator || item.owner != address(0))) {
          hasBoughtTickets = true;
        }
      }

      require(hasBoughtTickets == false, "Event has already sold tickets");

      for (uint index = 1; index <= _itemIds.current(); index++) {
        MarketItem storage item = idToMarketItem[index];

        if (item.eventId == eventId) {
		      item.status = ListingStatus.Cancelled;

		      IERC721(item.nftContract).transferFrom(address(this), eventData.creator, item.tokenId);
        }
      }

      eventData.status = EventListingStatus.Cancelled;
	  }

    function buyTicket(
    uint256 itemId
    ) public payable nonReentrant {
      uint price = idToMarketItem[itemId].price;
      uint tokenId = idToMarketItem[itemId].tokenId;
      Event memory eventData = idToEvents[idToMarketItem[itemId].eventId];
      uint eventFinalTime = eventData.eventFinalTime;

      require(msg.sender != idToMarketItem[itemId].seller, "Seller cannot be buyer");
      require(msg.sender != eventData.creator, "Creator cannot be buyer");
      require(msg.value >= price, "Insufficient payment");
      require(idToMarketItem[itemId].status == ListingStatus.Active, "Listing is not active");
      require(block.timestamp < eventFinalTime, "Event finished");
      require(idToMarketItem[itemId].used == false, "Ticket already used");

      idToMarketItem[itemId].owner = payable(msg.sender);
      idToMarketItem[itemId].status = ListingStatus.Sold;

      payable(owner()).transfer(msg.value / 100);

      address payable eventCreator = idToEvents[idToMarketItem[itemId].eventId].creator;
      
      if (idToMarketItem[itemId].seller != eventCreator) {
        eventCreator.transfer(msg.value / 100);
        idToMarketItem[itemId].seller.transfer(msg.value - (msg.value / 50));
      } else {
        idToMarketItem[itemId].seller.transfer(msg.value - (msg.value / 100));
      }

      IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
    } 

    function resellTicket(uint256 price, uint256 itemId) public {
      bool isUsed = idToMarketItem[itemId].used;
      uint eventFinalTime = idToEvents[idToMarketItem[itemId].eventId].eventFinalTime;

      require(isUsed == false, "Ticket already used");
      require(idToMarketItem[itemId].owner == msg.sender, "Not owner of ticket");
      require(block.timestamp < eventFinalTime, "Event finished");

      idToMarketItem[itemId] = MarketItem(
        itemId,
        idToMarketItem[itemId].eventId,
        idToMarketItem[itemId].nftContract,
        idToMarketItem[itemId].tokenId,
        payable(msg.sender),
        payable(address(0)),
        price,
        false,
        ListingStatus.Active
      );

      IERC721(idToMarketItem[itemId].nftContract).transferFrom(msg.sender, address(this), idToMarketItem[itemId].tokenId);  
    }

    function cancelTicketListing(uint itemId) public nonReentrant {
      MarketItem storage itemData = idToMarketItem[itemId];
      Event memory eventData = idToEvents[idToMarketItem[itemId].eventId];

      require(itemData.status == ListingStatus.Active, "Not listed ticket");
      require(itemData.seller == msg.sender, "Only seller can cancel");

      itemData.status = ListingStatus.Cancelled;

      IERC721(idToMarketItem[itemId].nftContract).transferFrom(address(this), msg.sender, idToMarketItem[itemId].tokenId);  
    }

    function useTicket(uint256 itemId) external {
      address eventCreator = idToEvents[idToMarketItem[itemId].eventId].creator;
      address owner = idToMarketItem[itemId].owner;
      bool isUsed = idToMarketItem[itemId].used;
      uint eventFinalTime = idToEvents[idToMarketItem[itemId].eventId].eventFinalTime;

      require(owner != address(0), "Ticket not bought yet");
      require(msg.sender == eventCreator || msg.sender == owner, "Not allowed to use ticket");
      require(isUsed == false, "Ticket already used");
      require(block.timestamp < eventFinalTime, "Event finished");

      idToMarketItem[itemId].used = true;
    }

    function getEventData(uint256 eventId) external view returns (Event memory) {
      return idToEvents[eventId];
    }

    function getEventTickets(uint256 eventId) external view returns (MarketItem[] memory) {
      Event memory eventData = idToEvents[eventId];
      MarketItem[] memory tickets = new MarketItem[](eventData.ticketsQuantity);
      uint currentTicketQuantity = 0;
      for (uint256 index = 1; index < _itemIds.current(); index++) {
        if (idToMarketItem[index].eventId == eventId) {
          tickets[currentTicketQuantity] = idToMarketItem[index];
          currentTicketQuantity++;
        }
      }
      return tickets;
    }

    function getMyTickets() external view returns (MarketItem[] memory) {
      uint ticketsQuantity = 0;
      for (uint256 index = 0; index < _itemIds.current(); index++) {
        MarketItem memory item = idToMarketItem[index + 1];
        if (item.owner == msg.sender || item.seller == msg.sender) {
          ticketsQuantity++;
        }
      }
      MarketItem[] memory tickets = new MarketItem[](ticketsQuantity);
      for (uint256 index = 0; index < _itemIds.current(); index++) {
        MarketItem memory item = idToMarketItem[index + 1];
        if (item.owner == msg.sender || item.seller == msg.sender) {
          tickets[index] = item;
        }
      }
      return tickets;
    }

    function getMyEvents() external view returns (Event[] memory) {
      uint eventsQuantity = 0;
      for (uint256 index = 0; index < _eventIds.current(); index++) {
        Event memory item = idToEvents[index + 1];
        if (item.creator == msg.sender) {
          eventsQuantity++;
        }
      }
      Event[] memory events = new Event[](eventsQuantity);
      for (uint256 index = 0; index < _eventIds.current(); index++) {
        Event memory item = idToEvents[index + 1];
        if (item.creator == msg.sender) {
          events[index] = item;
        }
      }
      return events;
    }
}