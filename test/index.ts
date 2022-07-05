import { expect } from "chai";
import { ethers } from "hardhat";
import { beforeEach } from "mocha";
import { Market } from "../typechain/Market";
import { NFT } from "../typechain/NFT";
import { 
  TOKEN_URI, 
  TICKET_QUANTITY, 
  EVENT_FINAL_TIME
} from "../utils/constants";

describe("NFT", function () {

  it("Should create all needed tickets", async function () {
    const Marketplace = await ethers.getContractFactory("Market");
    const marketplace = await Marketplace.deploy();
    await marketplace.deployed();

    const NFT = await ethers.getContractFactory("NFT");
    const nft = await NFT.deploy(marketplace.address);
    await nft.deployed();

    const tx = await nft.createTickets(TOKEN_URI, TICKET_QUANTITY);
    await tx.wait();

    expect(await nft.tokenURI(10)).to.equal(TOKEN_URI);
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

    let tx = await nft.createTickets(TOKEN_URI, TICKET_QUANTITY);
    await tx.wait();
  })

  it("Should create ticket market", async function () {
    const tx = await marketplace.createTicketMarket(nft.address, 15, 1, 10, EVENT_FINAL_TIME);
    await tx.wait();

    expect(await nft.ownerOf(10)).to.equal(marketplace.address);
  });

  it("Should buy ticket", async function () {
    const [owner, addr1] = await ethers.getSigners();

    let tx = await marketplace.createTicketMarket(nft.address, 15, 1, 10, EVENT_FINAL_TIME);
    await tx.wait();

    tx = await marketplace.connect(addr1).buyTicket(nft.address, 1, { value: 15}); 
    await tx.wait();

    expect(await nft.ownerOf(1)).to.equal(addr1.address);
    
  });

  it("Should resell a ticket", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    let tx = await marketplace.createTicketMarket(nft.address, 15, 1, 10, EVENT_FINAL_TIME);
    await tx.wait();

    tx = await marketplace.connect(addr1).buyTicket(nft.address, 1, { value: 15}); 
    await tx.wait();

    tx = await nft.connect(addr1).setApprovalForAll(marketplace.address, true);
    await tx.wait();

    tx = await marketplace.connect(addr1).resellTicket(15, 1);
    await tx.wait();

    tx = await marketplace.connect(addr2).buyTicket(nft.address, 1, { value: 15}); 
    await tx.wait();

    expect(await nft.ownerOf(1)).to.equal(addr2.address);
  });

  it("Should not resell an used ticket", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    let tx = await marketplace.createTicketMarket(nft.address, 15, 1, 10, EVENT_FINAL_TIME);
    await tx.wait();

    tx = await marketplace.connect(addr1).buyTicket(nft.address, 1, { value: 15}); 
    await tx.wait();

    tx = await marketplace.useTicket(1);
    await tx.wait();

    tx = await nft.connect(addr1).setApprovalForAll(marketplace.address, true);
    await tx.wait();

    await expect(marketplace.connect(addr1).resellTicket(15, 1)).to.be.revertedWith("Ticket already used");
  });

  it("Should not resell a not owned ticket", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    let tx = await marketplace.createTicketMarket(nft.address, 15, 1, 10, EVENT_FINAL_TIME);
    await tx.wait();

    tx = await marketplace.connect(addr1).buyTicket(nft.address, 1, { value: 15}); 
    await tx.wait();

    tx = await nft.connect(addr2).setApprovalForAll(marketplace.address, true);
    await tx.wait();

    await expect(marketplace.connect(addr2).resellTicket(15, 1)).to.be.revertedWith("Not owner of ticket");
  });

  it("Should not use an unbought ticket", async function () {
    let tx = await marketplace.createTicketMarket(nft.address, 15, 1, 10, EVENT_FINAL_TIME);
    await tx.wait();

    await expect(marketplace.useTicket(1)).to.be.revertedWith("Ticket not bought yet");
  });

  it("Ticket should not be used by third parties", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    let tx = await marketplace.createTicketMarket(nft.address, 15, 1, 10, EVENT_FINAL_TIME);
    await tx.wait();

    tx = await marketplace.connect(addr1).buyTicket(nft.address, 1, { value: 15}); 
    await tx.wait();

    await expect(marketplace.connect(addr2).useTicket(1)).to.be.revertedWith("Not allowed to use ticket");
  });

  it("Should not use an already used ticket", async function () {
    const [owner, addr1] = await ethers.getSigners();

    let tx = await marketplace.createTicketMarket(nft.address, 15, 1, 10, EVENT_FINAL_TIME);
    await tx.wait();

    tx = await marketplace.connect(addr1).buyTicket(nft.address, 1, { value: 15}); 
    await tx.wait();

    tx = await marketplace.connect(addr1).useTicket(1);
    await tx.wait();

    await expect(marketplace.connect(addr1).useTicket(1)).to.be.revertedWith("Ticket already used");
  });

  it("Should cancel ticket market", async function () {
    const [owner] = await ethers.getSigners();

    let tx = await marketplace.createTicketMarket(nft.address, 15, 1, 10, EVENT_FINAL_TIME);
    await tx.wait();

    tx = await marketplace.cancelTicketMarket(1, 10);
    await tx.wait();

    expect(await nft.ownerOf(10)).to.equal(owner.address);
  });
});