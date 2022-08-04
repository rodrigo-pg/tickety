// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./NFT.sol";

contract Market is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint;

    Counters.Counter private _eventIds;
    Counters.Counter private _itemIds;
    address private nftContract;

    enum Status {
      Created,
      Listed,
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
      Status status;
      string eventImage;
      string eventBanner;
      uint baseTicketPrice;
      uint ticketsAvailable;
    }

    struct MarketItem {
      uint itemId;
      uint eventId;
      address payable seller;
      address payable owner;
      uint256 price;
      bool used;
      Status status;
    }

    mapping(uint256 => Event) private idToEvents;
    mapping(uint256 => MarketItem) private idToMarketItem;

    function setNftContract(address newNftContract) external onlyOwner {
      nftContract = newNftContract;
    }

    function createEvent(
        uint ticketsQuantity,
        uint256 eventFinalTime,
        string memory eventName,
        string memory eventDescription,
        string memory eventImage,
        string memory eventBanner
    ) external nonReentrant {
      _eventIds.increment();

      uint eventId = _eventIds.current();

      idToEvents[eventId] = Event(
        eventId,
        eventName,
        eventDescription,
        payable(msg.sender),
        eventFinalTime,
        ticketsQuantity,
        Status.Created,
        eventImage,
        eventBanner,
        0,
        0
      );
    }

    function createTicketMarket(
    uint eventId,
    uint256 price
    ) public payable nonReentrant {
      require(price > 0, "Price must be at least 1 wei");

      Event storage eventData = idToEvents[eventId];

      require(msg.sender == eventData.creator, "Not event creator");
      require(eventData.status != Status.Listed, "Event already listed");
      require(block.timestamp < eventData.eventFinalTime, "Event already finished");

      eventData.baseTicketPrice = price;
      eventData.ticketsAvailable = eventData.ticketsQuantity;
      eventData.status = Status.Listed;
    }

    function cancelTicketMarket(uint eventId) public {
      Event storage eventData = idToEvents[eventId];

      require(eventData.status == Status.Listed, "Event not listed");
      require(msg.sender == eventData.creator, "Not event creator");
      require(eventData.ticketsQuantity == eventData.ticketsAvailable, "Event has already sold tickets");

      eventData.ticketsAvailable = 0;
      eventData.status = Status.Cancelled;
	  }

    function buyEventTicket(
    uint256 eventId
    ) public payable nonReentrant {
      Event storage eventData = idToEvents[eventId];
      uint eventFinalTime = eventData.eventFinalTime;

      require(msg.sender != eventData.creator, "Creator cannot be buyer");
      require(msg.value >= eventData.baseTicketPrice, "Insufficient payment");
      require(eventData.status == Status.Listed, "Event not listed");
      require(block.timestamp < eventFinalTime, "Event finished");
      require(eventData.ticketsAvailable > 0, "No tickets available");

      _itemIds.increment();
      uint itemId = _itemIds.current();

      idToMarketItem[itemId] = MarketItem(
          itemId,
          eventId,
          payable(address(0)),
          payable(msg.sender),
          0,
          false,
          Status.Sold
      );
      
      eventData.ticketsAvailable = eventData.ticketsAvailable.sub(1);

      payable(owner()).transfer(msg.value.div(100));
      eventData.creator.transfer(msg.value.div(100));
      idToMarketItem[itemId].seller.transfer(msg.value.sub(msg.value.div(100)));

      NFT(nftContract).mintTicket(itemId, eventData.creator, msg.sender);
      IERC721(nftContract).transferFrom(eventData.creator, msg.sender, itemId);
    }

    function buyTicket(
    uint256 itemId
    ) public payable nonReentrant {
      uint price = idToMarketItem[itemId].price;
      uint eventId = idToMarketItem[itemId].eventId;
      Event memory eventData = idToEvents[eventId];
      uint eventFinalTime = eventData.eventFinalTime;

      require(msg.sender != idToMarketItem[itemId].seller, "Seller cannot be buyer");
      require(msg.sender != eventData.creator, "Creator cannot be buyer");
      require(msg.value >= price, "Insufficient payment");
      require(eventData.status == Status.Listed, "Event not listed");
      require(idToMarketItem[itemId].status == Status.Listed, "Listing is not active");
      require(block.timestamp < eventFinalTime, "Event finished");
      require(idToMarketItem[itemId].used == false, "Ticket already used");

      idToMarketItem[itemId].owner = payable(msg.sender);
      idToMarketItem[itemId].status = Status.Sold;

      payable(owner()).transfer(msg.value.div(100));

      eventData.creator.transfer(msg.value.div(100));
      idToMarketItem[itemId].seller.transfer(msg.value.sub(msg.value.div(50)));
      IERC721(nftContract).transferFrom(address(this), msg.sender, itemId);
    } 

    function resellTicket(uint256 price, uint256 itemId) public {
      bool isUsed = idToMarketItem[itemId].used;
      uint eventId = idToMarketItem[itemId].eventId;
      Event memory eventData = idToEvents[eventId];

      require(isUsed == false, "Ticket already used");
      require(idToMarketItem[itemId].owner == msg.sender, "Not owner of ticket");
      require(block.timestamp < eventData.eventFinalTime, "Event finished");

      idToMarketItem[itemId] = MarketItem(
        itemId,
        idToMarketItem[itemId].eventId,
        payable(msg.sender),
        payable(address(0)),
        price,
        false,
        Status.Listed
      );

      NFT(nftContract).transferFrom(msg.sender, address(this), itemId);  
    }

    function cancelTicketListing(uint itemId) public nonReentrant {
      MarketItem storage itemData = idToMarketItem[itemId];

      require(itemData.status == Status.Listed, "Not listed ticket");
      require(itemData.seller == msg.sender, "Only seller can cancel");

      itemData.status = Status.Cancelled;

      NFT(nftContract).transferFrom(address(this), msg.sender, itemId);  
    }

    function useTicket(uint256 itemId) external {
      uint eventId = idToMarketItem[itemId].eventId;
      Event memory eventData = idToEvents[eventId];
      address eventCreator = eventData.creator;
      address owner = idToMarketItem[itemId].owner;
      bool isUsed = idToMarketItem[itemId].used;
      uint eventFinalTime = eventData.eventFinalTime;

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
      uint ticketsQuantity = 0;
      for (uint256 index = 0; index < _itemIds.current(); index++) {
        MarketItem memory item = idToMarketItem[index + 1];
        if (item.eventId == eventId) {
          ticketsQuantity++;
        }
      }
      MarketItem[] memory tickets = new MarketItem[](ticketsQuantity);
      for (uint256 index = 0; index < _itemIds.current(); index++) {
        MarketItem memory item = idToMarketItem[index + 1];
        if (item.eventId == eventId) {
          tickets[index] = item;
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