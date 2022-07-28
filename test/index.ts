import { expect } from "chai";
import { ethers } from "hardhat";
import { beforeEach } from "mocha";
import { Market } from "../typechain/Market";
import { NFT } from "../typechain/NFT";
import { 
  TOKEN_URI, 
  TICKET_QUANTITY, 
  EVENT_FINAL_TIME,
  EVENT_NAME,
  EVENT_DESCRIPTION,
  TICKET_PRICE,
  EVENT_IMAGE,
  EVENT_BANNER
} from "../utils/constants";

describe("NFT", function () {

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

  it("Should create all needed tickets", async function () {
    const [owner] = await ethers.getSigners();

    const tx = await nft.createTickets(TICKET_QUANTITY, EVENT_FINAL_TIME, EVENT_NAME, EVENT_DESCRIPTION, EVENT_IMAGE, EVENT_BANNER);
    await tx.wait();

    expect(await nft.ownerOf(10)).to.equal(owner.address);
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
    let tx = await nft.createTickets(TICKET_QUANTITY, EVENT_FINAL_TIME, EVENT_NAME, EVENT_DESCRIPTION, EVENT_IMAGE, EVENT_BANNER);
    await tx.wait();
  }

  async function listEventTickets() {
    const tx = await marketplace.createTicketMarket(1, TICKET_PRICE);
    await tx.wait();
  }

  it("Only authorized entity should be allowed to create event", async function () {
    const [owner] = await ethers.getSigners();

    await expect(marketplace.createEvent(
      TICKET_QUANTITY, 
      EVENT_FINAL_TIME, 
      EVENT_NAME, 
      EVENT_DESCRIPTION, 
      1, 
      owner.address, 
      EVENT_IMAGE, 
      EVENT_BANNER
    )).to.revertedWith("Not authorized to create");
  });

  it("Should list event's tickets", async function () {
    await createEvent();

    await listEventTickets();

    expect(await nft.ownerOf(10)).to.equal(marketplace.address);
  });

  it("Should not list an already listed event", async function () {
    await createEvent();

    await listEventTickets();

    await expect(listEventTickets()).to.revertedWith("Event already listed");
  });

  it("Should buy ticket", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    const tx = await marketplace.connect(addr1).buyTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    expect(await nft.ownerOf(1)).to.equal(addr1.address);
    
  });

  it("Creator Should not be allowed to buy a ticket", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await nft.connect(addr1).setApprovalForAll(marketplace.address, true);
    await tx.wait();

    tx = await marketplace.connect(addr1).resellTicket(TICKET_PRICE, 1);
    await tx.wait(); 

    await expect(marketplace.buyTicket(1, { value: TICKET_PRICE})).to.be.revertedWith("Creator cannot be buyer");
    
  });

  it("Should resell a ticket", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await nft.connect(addr1).setApprovalForAll(marketplace.address, true);
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

    let tx = await marketplace.connect(addr1).buyTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await marketplace.useTicket(1);
    await tx.wait();

    tx = await nft.connect(addr1).setApprovalForAll(marketplace.address, true);
    await tx.wait();

    await expect(marketplace.connect(addr1).resellTicket(TICKET_PRICE, 1)).to.be.revertedWith("Ticket already used");
  });

  it("Should not resell a not owned ticket", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await nft.connect(addr2).setApprovalForAll(marketplace.address, true);
    await tx.wait();

    await expect(marketplace.connect(addr2).resellTicket(TICKET_PRICE, 1)).to.be.revertedWith("Not owner of ticket");
  });

  it("Should cancel a ticket listing", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await nft.connect(addr1).setApprovalForAll(marketplace.address, true);
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

    let tx = await marketplace.connect(addr1).buyTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await nft.connect(addr1).setApprovalForAll(marketplace.address, true);
    await tx.wait();

    tx = await marketplace.connect(addr1).resellTicket(TICKET_PRICE, 1);
    await tx.wait();

    await expect(marketplace.connect(addr2).cancelTicketListing(1)).to.revertedWith("Only seller can cancel");

  });

  it("Should only cancel listed tickets", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await nft.connect(addr1).setApprovalForAll(marketplace.address, true);
    await tx.wait();

    await expect(marketplace.connect(addr1).cancelTicketListing(1)).to.revertedWith("Not listed ticket");

  });

  it("Should not use an unbought ticket", async function () {
    await createEvent();

    await listEventTickets();

    await expect(marketplace.useTicket(1)).to.be.revertedWith("Ticket not bought yet");
  });

  it("Ticket should not be used by third parties", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    const tx = await marketplace.connect(addr1).buyTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    await expect(marketplace.connect(addr2).useTicket(1)).to.be.revertedWith("Not allowed to use ticket");
  });

  it("Should not use an already used ticket", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    let tx = await marketplace.connect(addr1).buyTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    tx = await marketplace.connect(addr1).useTicket(1);
    await tx.wait();

    await expect(marketplace.connect(addr1).useTicket(1)).to.be.revertedWith("Ticket already used");
  });

  it("Should cancel ticket market", async function () {
    const [owner] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    const tx = await marketplace.cancelTicketMarket(1);
    await tx.wait();

    expect(await nft.ownerOf(10)).to.equal(owner.address);
  });

  it("Should not cancel ticket market with sale", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    const tx = await marketplace.connect(addr1).buyTicket(1, { value: TICKET_PRICE});
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
    await createEvent();

    await listEventTickets();

    let eventTickets = await marketplace.getEventTickets(1);

    expect(eventTickets.length).to.equal(10);
  });

  it("Should get event data", async function () {
    await createEvent();

    await listEventTickets();

    let eventData = await marketplace.getEventData(1);

    expect(eventData.length).to.equal(10);
  });

  it("Should get user's tickets", async function () {
    const [owner, addr1] = await ethers.getSigners();

    await createEvent();

    await listEventTickets();

    const tx = await marketplace.connect(addr1).buyTicket(1, { value: TICKET_PRICE}); 
    await tx.wait();

    let userTickets = await marketplace.connect(addr1).getMyTickets();

    expect(userTickets.length).to.equal(1);
  });

  it("Should get user's events", async function () {
    await createEvent();

    let userEvents = await marketplace.getMyEvents();

    expect(userEvents.length).to.equal(1);
  });
});