## ERC-1155 token standard implementation 

Practical implementation of the standard using an Escrow example.

Standard: https://eips.ethereum.org/EIPS/eip-1155

The solution is comprised of two Solidity Smart Contracts:
 - contracts/Escrow.sol
 - contracts/Tokens.sol

Main tool that is needed for testing and migrating is truffle:
https://github.com/trufflesuite/truffle/

### Tokens.sol
Handles the minting, transfering of Fungible and NonFungible tokens in a single contract.

### Escrow.sol
Holds all the escrow logic, like crediting, creating offers, handling orders..

Main token for value exchange is $ERC20 which is Fungible and users have to buy (credit) using ETH. Offers and orders can be created by any party. When an order is placed $ERC20 is deposited to the contract from the sender (buyer). The contract holds the deposit until and order is completed or complained. Offer owner (seller) is payed only if the order is completed by the sender (buyer).

NonFungible tokens are used to represent individual offers and orders. On order completion, the owner of the Offer NFT (seller) is payed the order amount.
Ownership of any Offer or Order can be transfered in an easy and standardized way.

Mixing of Fungible and NonFungible made generating IDs a bit complicated. There's a few approaches, described in the ERC1155 spec. I decided to generate NFT IDs using attributes from Offer/Order (so some need to be unique) and hardcode Fungible IDs (like $ERC20). The better approach would probably be to categorise NFTs and use their index in an individual category as the unique identifier. But for this simple use case it sufficed.

## Test
Tests are written in JS and can be found in `test` folder. Escrow.sol is fully tested, while the other contracts are not.

### Running

Code is executed and managed by truffle framework:
https://github.com/trufflesuite/truffle/

Make sure to have a recent version of node.js installed.

After cloning run in root folder:
```
npm i
```

For all tests run in root folder:

```
truffle test
```
