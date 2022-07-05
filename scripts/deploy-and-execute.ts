import { ethers } from "hardhat";
import { 
  TOKEN_URI, 
  TICKET_QUANTITY, 
  EVENT_FINAL_TIME
} from "../utils/constants";

async function main() {
  const [owner, addr1, addr2] = await ethers.getSigners();

  console.log("**** Deploying Marketplace and NFT");
  const Marketplace = await ethers.getContractFactory("Market");
  const marketplace = await Marketplace.deploy();
  await marketplace.deployed();

  const NFT = await ethers.getContractFactory("NFT");
  const nft = await NFT.deploy(marketplace.address);
  await nft.deployed();

  console.log("**** Creating Tickets");

  let tx = await nft.createTickets(TOKEN_URI, TICKET_QUANTITY);
  await tx.wait();

  console.log("**** Creating Ticket Market");

  tx = await marketplace.createTicketMarket(nft.address, 15, 1, 10, EVENT_FINAL_TIME);
  await tx.wait();

  console.log("**** Buying ticket");

  tx = await marketplace.connect(addr1).buyTicket(nft.address, 1, { value: 15}); 
  await tx.wait();

  console.log("**** Authorizing market to resell tickets");

  tx = await nft.connect(addr1).setApprovalForAll(marketplace.address, true);
  await tx.wait();

  console.log("**** Reselling ticket");

  tx = await marketplace.connect(addr1).resellTicket(15, 1);
  await tx.wait();

  console.log("**** Rebuying ticket");

  tx = await marketplace.connect(addr2).buyTicket(nft.address, 1, { value: 15}); 
  await tx.wait();

  console.log("**** Using ticket");

  tx = await marketplace.connect(addr2).useTicket(1);
  await tx.wait();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
