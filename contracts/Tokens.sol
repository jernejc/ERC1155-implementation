
pragma solidity ^0.6.2;

import "./ERC1155MixedFungible.sol";

/**
  @dev MixedFungibleMintable form of ERC1155 - https://eips.ethereum.org/EIPS/eip-1155
  Using ERC 1155, we can handle all token standards (ERC721, ERC20) in a single contract

  Simple example of Fungible and NonFungible mint, needs batch support
  Based on: https://raw.githubusercontent.com/enjin/erc-1155/master/contracts/ERC1155MixedFungibleMintable.sol
*/
contract Tokens is ERC1155MixedFungible {

  uint256 public constant ERC20_TOKEN_ID = 1; // Token ID for ERC20, Fungible
  uint256 public constant CONVERSION_RATE = 10; // Fixed conversion rate for ERC20 from ETH

  constructor() public ERC1155MixedFungible() {
    // run mixedfungible constructor
  }

  function mintNonFungible(address _to, uint256 _id)
    external
  {
    require(!_exists(_id), "Tokens: NFT must not exist when minting");

    // Keep track of NFT owners
    nftOwners.set(_id, _to);

    // Set balances
    balances[_id][_to] = 1;

    // Emit the Transfer/Mint event.
    emit TransferSingle(_msgSender(), address(0x0), _to, _id, 1);

    if (_to.isContract()) {
      _doSafeTransferAcceptanceCheck(
        _msgSender(),
        _msgSender(),
        _to,
        _id,
        1,
        ""
      );
    }
  }

  function mintFungible(
    address _to,
    uint256 _id,
    uint256 _amount
  ) external {
    require(!_existsNonFungible(_id), "Tokens: _id must be Fungable when minting");

    // Keep track of totalSupply
    ftTotalSupply[_id] = _amount.add(ftTotalSupply[_id]);

    // Set balances
    balances[_id][_to] = _amount.add(balances[_id][_to]);

    // Emit the Transfer/Mint event.
    emit TransferSingle(_msgSender(), address(0x0), _to, _id, _amount);

    if (_to.isContract()) {
      _doSafeTransferAcceptanceCheck(
        _msgSender(),
        _msgSender(),
        _to,
        _id,
        _amount,
        ""
      );
    }
  }
}
