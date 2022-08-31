// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./NFT.sol";

contract Market is Ownable {

    using ECDSA for bytes32;
    using Counters for Counters.Counter;
    using SafeMath for uint;

    Counters.Counter private _eventIds;
    Counters.Counter private _itemIds;
    address private nftContract;

    mapping(uint256 => Event) private idToEvents;
    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(address => uint) private holdersTicketsQuantity;
    mapping(address => uint) private creatorsEventsQuantity;

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
      uint256 eventStartTime;
      string location;
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

    function setNftContract(address newNftContract) external onlyOwner {
      nftContract = newNftContract;
    }

    function createEvent(
        uint ticketsQuantity,
        uint256 eventFinalTime,
        uint256 eventStartTime,
        string memory eventName,
        string memory eventDescription,
        string memory eventImage,
        string memory eventBanner,
        string memory location
    ) external {
      require(eventStartTime < eventFinalTime, "Invalid dates");

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
        0,
        eventStartTime,
        location
      );

      creatorsEventsQuantity[msg.sender] = creatorsEventsQuantity[msg.sender].add(1);
    }

    function createTicketMarket(
    uint eventId,
    uint256 price
    ) public payable {
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
    ) public payable {
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
      holdersTicketsQuantity[msg.sender] = holdersTicketsQuantity[msg.sender].add(1);

      payRoyalties(eventData.creator, idToMarketItem[itemId].seller);

      NFT(nftContract).mintTicket(itemId, eventData.creator, msg.sender);
      IERC721(nftContract).transferFrom(eventData.creator, msg.sender, itemId);
    }

    function buyTicket(
    uint256 itemId
    ) public payable {
      uint eventId = idToMarketItem[itemId].eventId;
      Event memory eventData = idToEvents[eventId];

      require(msg.sender != idToMarketItem[itemId].seller, "Seller cannot be buyer");
      require(msg.sender != eventData.creator, "Creator cannot be buyer");
      require(msg.value >= idToMarketItem[itemId].price, "Insufficient payment");
      require(eventData.status == Status.Listed, "Event not listed");
      require(idToMarketItem[itemId].status == Status.Listed, "Listing is not active");
      require(block.timestamp < eventData.eventFinalTime, "Event finished");
      require(idToMarketItem[itemId].used == false, "Ticket already used");

      holdersTicketsQuantity[msg.sender] = holdersTicketsQuantity[msg.sender].add(1);
      holdersTicketsQuantity[idToMarketItem[itemId].seller] = holdersTicketsQuantity[idToMarketItem[itemId].seller].sub(1);
      idToMarketItem[itemId].owner = payable(msg.sender);
      idToMarketItem[itemId].status = Status.Sold;

      payRoyalties(eventData.creator, idToMarketItem[itemId].seller);

      IERC721(nftContract).transferFrom(address(this), msg.sender, itemId);
    } 

    function resellTicket(uint256 price, uint256 itemId) public {
      uint eventId = idToMarketItem[itemId].eventId;
      Event memory eventData = idToEvents[eventId];

      require(idToMarketItem[itemId].used == false, "Ticket already used");
      require(idToMarketItem[itemId].owner == msg.sender, "Not owner of ticket");
      require(block.timestamp < eventData.eventFinalTime, "Event finished");
      require(eventData.ticketsAvailable == 0, "Reselling not available yet");

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

    function cancelTicketListing(uint itemId) public {
      require(idToMarketItem[itemId].status == Status.Listed, "Not listed ticket");
      require(idToMarketItem[itemId].seller == msg.sender, "Only seller can cancel");

      idToMarketItem[itemId].status = Status.Cancelled;

      NFT(nftContract).transferFrom(address(this), msg.sender, itemId);  
    }

    function useTicket(uint256 itemId, bytes calldata signature) external {
      require(idToMarketItem[itemId].owner != address(0), "Ticket not bought yet");

      bytes32 hashDomain = keccak256(
        abi.encode(
            keccak256(
                "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
            ),
            keccak256(bytes("TicketyMarket")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        )
      );
      bytes32 hashEntrance = keccak256(
        abi.encode(
            keccak256("Ticket(uint256 id)"),
            itemId
        )
      );

      address signer = keccak256(abi.encodePacked("\x19\x01", hashDomain, hashEntrance)).recover(signature);

      uint eventId = idToMarketItem[itemId].eventId;
      Event memory eventData = idToEvents[eventId];

      require(msg.sender == eventData.creator && signer == idToMarketItem[itemId].owner, "Not allowed to use ticket");
      require(idToMarketItem[itemId].used == false, "Ticket already used");
      require(block.timestamp < eventData.eventFinalTime, "Event finished");

      idToMarketItem[itemId].used = true;
    }

    function payRoyalties(address payable eventCreator, address payable seller) private {
      payable(owner()).transfer(msg.value.div(100));
      eventCreator.transfer(msg.value.div(100));
      seller.transfer(msg.value.sub(2 * msg.value.div(100)));
    }

    function getEventData(uint256 eventId) external view returns (Event memory) {
      return idToEvents[eventId];
    }

    function getEventTickets(uint256 eventId) external view returns (MarketItem[] memory) {
      Event memory eventData = idToEvents[eventId];
      MarketItem[] memory tickets = new MarketItem[](eventData.ticketsQuantity - eventData.ticketsAvailable);
      uint nextTicketPosition = 0;
      for (uint256 index = 0; index < _itemIds.current(); index++) {
        MarketItem memory item = idToMarketItem[index + 1];
        if (item.eventId == eventId) {
          tickets[nextTicketPosition] = item;
          nextTicketPosition++;
        }
      }
      return tickets;
    }

    function getMyTickets() external view returns (MarketItem[] memory) {
      MarketItem[] memory tickets = new MarketItem[](holdersTicketsQuantity[msg.sender]);
      uint nextTicketPosition = 0;
      for (uint256 index = 0; index < _itemIds.current(); index++) {
        MarketItem memory item = idToMarketItem[index + 1];
        if (item.owner == msg.sender || item.seller == msg.sender) {
          tickets[nextTicketPosition] = item;
          nextTicketPosition++;
        }
      }
      return tickets;
    }

    function getMyEvents() external view returns (Event[] memory) {
      Event[] memory events = new Event[](creatorsEventsQuantity[msg.sender]);
      uint nextEventPosition = 0;
      for (uint256 index = 0; index < _eventIds.current(); index++) {
        Event memory item = idToEvents[index + 1];
        if (item.creator == msg.sender) {
          events[nextEventPosition] = item;
          nextEventPosition++;
        }
      }
      return events;
    }
}