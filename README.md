# Tickety

The goal of tickety is to create a market around 
event's tickets by the reselling of tickets between
users and in this reselling the event's creator will
receive a fee of the transaction. Thus, the event
will become more profitable to the creator and with a
low waste of entrances.

## Concepts

Tickety was made using the following major concepts within
the Ethereum ecosystem:
* ERC721 - NFT Standard
* EIP712 - Standard for signing typed data that belongs to a domain
* Lazy Minting - For low cost transactions
* NFT Royalties

## Using

The application uses the ERC721 standard to represent the tickets as
NFTs, and uses the Lazy Minting technique to reduce the cost of minting
of the tickets, further more it uses the EIP712 so that the users can generate an
entrance that's a signature containing the id of the ticket that they want
to use and present this entrance in the event so it can be verified.