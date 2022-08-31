import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { beforeEach } from "mocha";
import { Market } from "../typechain/Market";
import { NFT } from "../typechain/NFT";
import {  
  TICKET_QUANTITY, 
  EVENT_FINAL_TIME,
  EVENT_NAME,
  EVENT_DESCRIPTION,
  TICKET_PRICE,
  EVENT_IMAGE,
  EVENT_BANNER,
  LOCATION,
  EVENT_START_TIME
} from "../utils/constants";

describe("NFT", function () {

  let marketplace:Market;
  let nft:NFT;

  beforeEach(async () => {
    const Marketplace = await ethers.getContractFactory("Market");
    //marketplace = (await upgrades.deployProxy(Marketplace, { initializer: "store" })) as Market;
    marketplace = await Marketplace.deploy();
    await marketplace.deployed();

    const NFT = await ethers.getContractFactory("NFT");
    //nft = (await upgrades.deployProxy(NFT, [marketplace.address], { initializer: "store" })) as NFT;
    nft = await NFT.deploy(marketplace.address);
    await nft.deployed();

    marketplace.setNftContract(nft.address);
  })

  it("Only market should mint tickets", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await expect(nft.mintTicket(1, owner.address, addr1.address)).to.be.revertedWith("Not authorized to mint");
  });
});

describe("Market", function () {

  let marketplace:Market;
  let nft:NFT;

  beforeEach(async () => {
    const Marketplace = await ethers.getContractFactory("Market");
    marketplace = await Marketplace.deploy();
    await marketplace.deployed();

    const NFT = await ethers.getContractFactory("NFT");
    nft = await NFT.deploy(marketplace.address);
    await nft.deployed();

    marketplace.setNftContract(nft.address);
  })

  async function createEvent() {
    let tx = await marketplace.createEvent(
      TICKET_QUANTITY, 
      EVENT_FINAL_TIME, 
      EVENT_START_TIME,
      EVENT_NAME, 
      EVENT_DESCRIPTION, 
      EVENT_IMAGE, 
      EVENT_BANNER,
      LOCATION
    );
    await tx.wait();
  }

  async function listEventTickets() {
    const tx = await marketplace.createTicketMarket(1, TICKET_PRICE);
    await tx.wait();
  }

  async function generateEntrance(signer: SignerWithAddress, ticketId: number) {
    const domain = {
      name: 'TicketyMarket',
      version: '1',
      chainId: await signer.getChainId(),
      verifyingContract: marketplace.address
    };

    const types = {
      Ticket: [
        { name: "id", type: "uint256" }
      ] 
    };

    const ticket = {
      id: ticketId
    };

    return await signer._signTypedData(domain, types, ticket);
  }

  it("Should list event's tickets", async function () {
    await createEvent();

    await listEventTickets();

    const eventData = await marketplace.getEventData(1);
    const status = eventData[6].toString();

    expect(status).to.equal("1");
  });

  it("Should not list an already listed event", async function () {
    await createEvent();

    await listEventTickets();

    await expect(listEventTickets()).to.revertedWith("Event already listed");
  });

  it("Should buy event ticket", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    expect(await nft.ownerOf(1)).to.equal(addr1.address);
  });

  it("Creator should not be allowed to buy a event ticket", async function () {
    await createEvent();

    await listEventTickets();

    await expect(marketplace.buyEventTicket(1, { value: TICKET_PRICE})).to.be.revertedWith("Creator cannot be buyer");
    
  });

  it("Should not buy event ticket with insufficient payment", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    await expect(marketplace.connect(addr1).buyEventTicket(1, { value: 1})).to.be.revertedWith("Insufficient payment");
  });

  it("Creator should not be allowed to buy a user's ticket", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await marketplace.connect(addr1).resellTicket(TICKET_PRICE, 1);
    await tx.wait(); 

    await expect(marketplace.buyTicket(1, { value: TICKET_PRICE})).to.be.revertedWith("Creator cannot be buyer");
    
  });

  it("Should not be allowed to buy event tickets from unlisted events", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.cancelTicketMarket(1);
    await tx.wait();

    await expect(marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE})).to.be.revertedWith("Event not listed");
    
  });

  it("Should not be allowed to buy event tickets with no tickets avaiable", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    for (let index = 0; index < TICKET_QUANTITY; index++) {
      await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE});
    }

    await expect(marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE})).to.be.revertedWith("No tickets available");
    
  });

  it("Should resell a ticket", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await marketplace.connect(addr1).resellTicket(TICKET_PRICE, 1);
    await tx.wait();

    tx = await marketplace.connect(addr2).buyTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    expect(await nft.ownerOf(1)).to.equal(addr2.address);
  });

  it("Should not resell an used ticket", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    const entrance = await generateEntrance(addr1, 1);

    tx = await marketplace.useTicket(1, entrance);
    await tx.wait();

    await expect(marketplace.connect(addr1).resellTicket(TICKET_PRICE, 1)).to.be.revertedWith("Ticket already used");
  });

  it("Should not resell a not owned ticket", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    const tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    await expect(marketplace.connect(addr2).resellTicket(TICKET_PRICE, 1)).to.be.revertedWith("Not owner of ticket");
  });

  it("Seller should not buy a ticket for event", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await marketplace.connect(addr1).resellTicket(TICKET_PRICE, 1);
    await tx.wait();

    await expect(marketplace.connect(addr1).buyTicket(1)).to.be.revertedWith("Seller cannot be buyer");
  });

  it("Should not buy a ticket with insufficient payment", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await marketplace.connect(addr1).resellTicket(TICKET_PRICE, 1);
    await tx.wait();

    await expect(marketplace.connect(addr2).buyTicket(1, { value: 1})).to.be.revertedWith("Insufficient payment");
  });

  it("Should not buy an unlisted ticket", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    await expect(marketplace.connect(addr2).buyTicket(1, { value: 1})).to.be.revertedWith("Listing is not active");
  });

  it("Creator should not buy a ticket for event", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await marketplace.connect(addr1).resellTicket(TICKET_PRICE, 1);
    await tx.wait();

    await expect(marketplace.buyTicket(1)).to.be.revertedWith("Creator cannot be buyer");
  });

  it("Should cancel a ticket listing", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await marketplace.connect(addr1).resellTicket(TICKET_PRICE, 1);
    await tx.wait();

    expect(await nft.ownerOf(1)).to.equal(marketplace.address);

    tx = await marketplace.connect(addr1).cancelTicketListing(1); 
    await tx.wait();

    expect(await nft.ownerOf(1)).to.equal(addr1.address);
  });

  it("Only seller should cancel a ticket listing", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await marketplace.connect(addr1).resellTicket(TICKET_PRICE, 1);
    await tx.wait();

    await expect(marketplace.connect(addr2).cancelTicketListing(1)).to.revertedWith("Only seller can cancel");

  });

  it("Should only cancel listed tickets", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    await expect(marketplace.connect(addr1).cancelTicketListing(1)).to.revertedWith("Not listed ticket");

  });

  it("Should not use an unbought ticket", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    const entrance = await generateEntrance(addr1, 1);

    await expect(marketplace.useTicket(1, entrance)).to.be.revertedWith("Ticket not bought yet");
  });

  it("Ticket should not be used by third parties", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    const tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    const entrance = await generateEntrance(addr1, 1);

    await expect(marketplace.connect(addr2).useTicket(1, entrance)).to.be.revertedWith("Not allowed to use ticket");
  });

  it("Should not use an already used ticket", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    const entrance = await generateEntrance(addr1, 1);

    tx = await marketplace.useTicket(1, entrance);
    await tx.wait();

    await expect(marketplace.useTicket(1, entrance)).to.be.revertedWith("Ticket already used");
  });

  it("Should cancel ticket market", async function () {
    await createEvent();

    await listEventTickets();

    const tx = await marketplace.cancelTicketMarket(1);
    await tx.wait();

    const eventData = await marketplace.getEventData(1);
    const status = eventData[6].toString();

    expect(status).to.equal("3");
  });

  it("Should not cancel ticket market with sale", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    const tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE});
    tx.wait();

    await expect(marketplace.cancelTicketMarket(1)).to.be.revertedWith("Event has already sold tickets");
  });

  it("Should not cancel unlisted ticket market", async function () {
    await createEvent();

    await expect(marketplace.cancelTicketMarket(1)).to.be.revertedWith("Event not listed");
  });

  it("Only event creator should be allowed to cancel", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    await expect(marketplace.connect(addr1).cancelTicketMarket(1)).to.be.revertedWith("Not event creator");
  });

  it("Should get event tickets", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    let eventTickets = await marketplace.getEventTickets(1);

    expect(eventTickets.length).to.equal(1);
    expect(eventTickets[0][0].toString()).to.equal("1");
  });

  it("Should get event data", async function () {
    await createEvent();

    await listEventTickets();

    let eventData = await marketplace.getEventData(1);

    expect(eventData.length).to.equal(13);
  });

  it("Should get user's tickets", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    const tx = await marketplace.connect(addr1).buyEventTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    let userTickets = await marketplace.connect(addr1).getMyTickets();

    expect(userTickets.length).to.equal(1);
  });

  it("Should get user's events", async function () {
    await createEvent();

    let userEvents = await marketplace.getMyEvents();

    console.log(userEvents)

    expect(userEvents.length).to.equal(1);
  });
});