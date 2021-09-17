
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/utils/EnumerableMap.sol";
import "./ERC1155.sol";

/**
@dev Extension to ERC1155 for Mixed Fungible and Non-Fungible Items support
The main benefit is sharing of common type information, just like you do when
creating a fungible id.

Based on: https://github.com/enjin/erc-1155/blob/master/contracts/ERC1155MixedFungible.sol
*/
contract ERC1155MixedFungible is ERC1155 {

  using EnumerableMap for EnumerableMap.UintToAddressMap;

  // Enumerable mapping from NonFungable ids to their owners
  EnumerableMap.UintToAddressMap internal nftOwners;
  
  // Total supply for Fungables
  mapping (uint256 => uint256) internal ftTotalSupply;

  // override
  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _id,
    uint256 _value,
    bytes memory _data
  ) public virtual override {
    require(
      _to != address(0x0),
      "ERC1155MixedFungible: Cannot send to zero address"
    );
    require(
      _from == _msgSender() || isApprovedForAll(_from, _msgSender()),
      "ERC1155MixedFungible: Need operator approval for 3rd party transfers."
    );

    if (_existsNonFungible(_id)) {
      require(
        nftOwners.get(_id) == _from,
        "ERC1155MixedFungible: From must match previous owner"
      );

      balances[_id][_from] = 0;
      balances[_id][_to] = 1;
      nftOwners.set(_id, _to);
    } else {
      balances[_id][_from] = balances[_id][_from].sub(_value);
      balances[_id][_to] = balances[_id][_to].add(_value);
    }

    emit TransferSingle(_msgSender(), _from, _to, _id, _value);

    if (_to.isContract()) {
      _doSafeTransferAcceptanceCheck(
        _msgSender(),
        _from,
        _to,
        _id,
        _value,
        _data
      );
    }
  }

  // override
  function safeBatchTransferFrom(
    address _from,
    address _to,
    uint256[] memory _ids,
    uint256[] memory _values,
    bytes memory _data
  ) public virtual override {
    require(
      _to != address(0x0),
      "ERC1155MixedFungible: Cannot send to zero address"
    );
    require(
      _ids.length == _values.length,
      "ERC1155MixedFungible: Array length must match"
    );

    // Only supporting a global operator approval allows us to do only 1 check and not to touch storage to handle allowances.
    require(
      _from == _msgSender() || isApprovedForAll(_from, _msgSender()),
      "ERC1155MixedFungible: Need operator approval for 3rd party transfers."
    );

    for (uint256 i = 0; i < _ids.length; ++i) {
      // Cache value to local variable to reduce read costs.
      uint256 id = _ids[i];
      uint256 value = _values[i];

      if (_existsNonFungible(id)) {
        require(
          nftOwners.get(id) == _from,
          "ERC1155MixedFungible: From must match previous owner"
        );
        balances[id][_from] = 0;
        balances[id][_to] = 1;
        nftOwners.set(id, _to);
      } else {
        balances[id][_from] = balances[id][_from].sub(value);
        balances[id][_to] = value.add(balances[id][_to]);
      }
    }

    emit TransferBatch(_msgSender(), _from, _to, _ids, _values);

    if (_to.isContract()) {
      _doSafeBatchTransferAcceptanceCheck(
        _msgSender(),
        _from,
        _to,
        _ids,
        _values,
        _data
      );
    }
  }

  // override
  function balanceOf(address _owner, uint256 _id)
    public view virtual override
    returns (uint256)
  {
    return balances[_id][_owner];
  }

  // override
  function balanceOfBatch(address[] memory _owners, uint256[] memory _ids)
    public view virtual override
    returns (uint256[] memory)
  {
    require(
      _owners.length == _ids.length,
      "ERC1155MixedFungible: _owners and _ids must match in length"
    );

    uint256[] memory balances_ = new uint256[](_owners.length);

    for (uint256 i = 0; i < _owners.length; ++i) {
      balances_[i] = balances[_ids[i]][_owners[i]];
    }

    return balances_;
  }

  // Internal Helpers
  function _ownerOfNonFungible(uint256 _id) internal view returns (address) {
    return nftOwners.get(_id, "ERC1155MixedFungible: owner query for nonexistent token");
  }

  function _exists(uint256 _id) internal view returns (bool) {
    return _existsNonFungible(_id) || _existsFungible(_id);
  }

  function _existsFungible(uint256 _id) internal view returns (bool) {
    return ftTotalSupply[_id] > 0;
  }

  function _existsNonFungible(uint256 _id) internal view returns (bool) {
    return nftOwners.contains(_id);
  }

  // Public helpers
  function exists(uint256 _id) public view returns (bool) {
    return _exists(_id);
  }
  
  function ownerOfNonFungible(uint256 _id) public view returns (address) {
    return _ownerOfNonFungible(_id);
  }
}
