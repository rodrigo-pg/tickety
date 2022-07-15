// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFT is ERC721URIStorage, ReentrancyGuard {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemIds;
    Counters.Counter private _eventIds;

    enum ListingStatus {
	    Active,
	    Sold,
	    Cancelled
	}

    struct Event {
      uint eventId;
      string eventName;
      string eventDescription;
      address payable creator;
      uint256 eventFinalTime;
      uint256 ticketsQuantity;
      uint256 initialTokenId;
    }

    struct MarketItem {
      uint itemId;
      uint eventId;
      uint256 tokenId;
      address payable seller;
      address payable owner;
      uint256 price;
      bool used;
      ListingStatus status;
    }

    mapping(uint256 => Event) private idToEvents;
    mapping(uint256 => MarketItem) private idToMarketItem;
    //mapping(uint256 => address) private ticketsByEventCreators;

    constructor() ERC721("TicketMarket", "TTM") {}   

    function createEvent(
        uint ticketQuantity,
        uint256 eventFinalTime,
        string memory eventName,
        string memory eventDescription
    ) public returns (uint) {

        _tokenIds.increment();
        _eventIds.increment();
        uint256 eventId = _eventIds.current();

        idToEvents[eventId] = Event(
            eventId,
            eventName,
            eventDescription,
            payable(msg.sender),
            eventFinalTime,
            ticketQuantity,
            _itemIds.current()
        );

        for (uint256 index = 0; index < ticketQuantity; index++) {
            uint256 newItemId = _tokenIds.current();
            _mint(msg.sender, newItemId);
        }
    }

    function sellEventTickets(
    uint eventId,
    uint price
    ) public payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");

        Event memory requestedEvent = idToEvents[eventId];
        require(requestedEvent.creator == msg.sender, "Not event creator");

        uint initialTokenId = requestedEvent.initialTokenId;
        uint finalTokenId = initialTokenId + requestedEvent.ticketsQuantity;

        for (initialTokenId; initialTokenId <= finalTokenId; initialTokenId++) {

            uint256 itemId = _itemIds.current();

            idToMarketItem[itemId] = MarketItem(
              itemId,
              eventId,
              initialTokenId,
              payable(msg.sender),
              payable(address(0)),
              price,
              false,
              ListingStatus.Active
            );

            //ticketsByEventCreators[initialTokenId] = msg.sender;

            transferFrom(msg.sender, address(this), initialTokenId);

            //IERC721(nftContract).transferFrom(msg.sender, address(this), initialTokenId);

            _itemIds.increment();
        }
    }

    function cancelTicketMarket(uint256 initialItemId, uint256 finalItemId) public nonReentrant {
        for (initialItemId; initialItemId <= finalItemId; initialItemId++) {
            MarketItem storage item = idToMarketItem[initialItemId];

		    require(msg.sender == item.seller, "Only seller can cancel listing");
		    require(item.status == ListingStatus.Active, "Listing is not active");

		    item.status = ListingStatus.Cancelled;

		    //IERC721(item.nftContract).transferFrom(address(this), msg.sender, item.tokenId);
            transferFrom(address(this), msg.sender, item.tokenId);
        }
	  }

    function buyTicket(
    uint256 itemId
    ) public payable nonReentrant {
      uint price = idToMarketItem[itemId].price;
      uint tokenId = idToMarketItem[itemId].tokenId;
      uint eventFinalTime = idToEvents[idToMarketItem[itemId].eventId].eventFinalTime;

      require(msg.sender != idToMarketItem[itemId].seller, "Seller cannot be buyer");
      require(msg.value >= price, "Insufficient payment");
      require(idToMarketItem[itemId].status == ListingStatus.Active, "Listing is not active");
      require(block.timestamp < eventFinalTime, "Event finished");
      require(idToMarketItem[itemId].used == false, "Ticket already used");

      idToMarketItem[itemId].owner = payable(msg.sender);
      idToMarketItem[itemId].status = ListingStatus.Sold;

      //payable(owner()).transfer(msg.value / 100);

      address payable eventCreator = idToEvents[idToMarketItem[itemId].eventId].creator;
      
      if (idToMarketItem[itemId].seller != eventCreator) {
        eventCreator.transfer(msg.value / 100);
        idToMarketItem[itemId].seller.transfer(msg.value - (msg.value / 50));
      } else {
        idToMarketItem[itemId].seller.transfer(msg.value - (msg.value / 100));
      }

      transferFrom(address(this), msg.sender, tokenId);
    } 

    function resellTicket(uint256 price, uint256 itemId) public {
      bool isUsed = idToMarketItem[itemId].used;
      uint eventFinalTime = idToEvents[idToMarketItem[itemId].eventId].eventFinalTime;

      require(isUsed == false, "Ticket already used");
      require(idToMarketItem[itemId].owner == msg.sender, "Not owner of ticket");
      require(block.timestamp < eventFinalTime, "Event finished");

      address payable eventCreator = idToEvents[idToMarketItem[itemId].eventId].creator;

      idToMarketItem[itemId] = MarketItem(
        itemId,
        idToMarketItem[itemId].eventId,
        idToMarketItem[itemId].tokenId,
        payable(msg.sender),
        payable(address(0)),
        price,
        false,
        ListingStatus.Active
      );

      transferFrom(msg.sender, address(this), idToMarketItem[itemId].tokenId);  
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
      uint initialItemId = eventData.initialTokenId;
      uint finalItemId = initialItemId + eventData.ticketsQuantity;
      for (uint256 index = 0; index < eventData.ticketsQuantity; index++) {
        tickets[index] = idToMarketItem[initialItemId + index];
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