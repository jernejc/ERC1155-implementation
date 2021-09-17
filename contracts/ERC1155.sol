
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
@dev An implementation of core ERC1155 function.

Based on: https://github.com/enjin/erc-1155/blob/master/contracts/ERC1155.sol
*/
contract ERC1155 is IERC1155, ERC165, Context
{
  using SafeMath for uint256;
  using Address for address;

  // id => (owner => balance)
  mapping (uint256 => mapping(address => uint256)) internal balances;

  // owner => (operator => approved)
  mapping (address => mapping(address => bool)) private _operatorApprovals;

  /*
    *     bytes4(keccak256('balanceOf(address,uint256)')) == 0x00fdd58e
    *     bytes4(keccak256('balanceOfBatch(address[],uint256[])')) == 0x4e1273f4
    *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
    *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
    *     bytes4(keccak256('safeTransferFrom(address,address,uint256,uint256,bytes)')) == 0xf242432a
    *     bytes4(keccak256('safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)')) == 0x2eb2c2d6
    *
    *     => 0x00fdd58e ^ 0x4e1273f4 ^ 0xa22cb465 ^
    *        0xe985e9c5 ^ 0xf242432a ^ 0x2eb2c2d6 == 0xd9b67a26
    */
  bytes4 private constant _INTERFACE_ID_ERC1155 = 0xd9b67a26;

  /*
    *     bytes4(keccak256('uri(uint256)')) == 0x0e89341c
    */
  bytes4 private constant _INTERFACE_ID_ERC1155_METADATA_URI = 0x0e89341c;

  /**
    * @dev See {_setURI}.
    */
  constructor () public {
    // register the supported interfaces to conform to ERC1155 via ERC165
    _registerInterface(_INTERFACE_ID_ERC1155);

    // register the supported interfaces to conform to ERC1155MetadataURI via ERC165
    _registerInterface(_INTERFACE_ID_ERC1155_METADATA_URI);
  }

  /**
    @notice Transfers `_value` amount of an `_id` from the `_from` address to the `_to` address specified (with safety call).
    @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
    MUST revert if `_to` is the zero address.
    MUST revert if balance of holder for token `_id` is lower than the `_value` sent.
    MUST revert on any other error.
    MUST emit the `TransferSingle` event to reflect the balance change (see "Safe Transfer Rules" section of the standard).
    After the above conditions are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call `onERC1155Received` on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).
    @param _from    Source address
    @param _to      Target address
    @param _id      ID of the token type
    @param _value   Transfer amount
    @param _data    Additional data with no specified format, MUST be sent unaltered in call to `onERC1155Received` on `_to`
  */
  function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes memory _data) public virtual override {

    require(_to != address(0x0), "_to must be non-zero.");
    require(_from == _msgSender() || isApprovedForAll(_from, _msgSender()), "Need operator approval for 3rd party transfers.");

    // SafeMath will throw with insuficient funds _from
    // or if _id is not valid (balance will be 0)
    balances[_id][_from] = balances[_id][_from].sub(_value);
    balances[_id][_to]   = _value.add(balances[_id][_to]);

    // MUST emit event
    emit TransferSingle(_msgSender(), _from, _to, _id, _value);

    // Now that the balance is updated and the event was emitted,
    // call onERC1155Received if the destination is a contract.
    if (_to.isContract()) {
      _doSafeTransferAcceptanceCheck(_msgSender(), _from, _to, _id, _value, _data);
    }
  }

  /**
    @notice Transfers `_values` amount(s) of `_ids` from the `_from` address to the `_to` address specified (with safety call).
    @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
    MUST revert if `_to` is the zero address.
    MUST revert if length of `_ids` is not the same as length of `_values`.
    MUST revert if any of the balance(s) of the holder(s) for token(s) in `_ids` is lower than the respective amount(s) in `_values` sent to the recipient.
    MUST revert on any other error.
    MUST emit `TransferSingle` or `TransferBatch` event(s) such that all the balance changes are reflected (see "Safe Transfer Rules" section of the standard).
    Balance changes and events MUST follow the ordering of the arrays (_ids[0]/_values[0] before _ids[1]/_values[1], etc).
    After the above conditions for the transfer(s) in the batch are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call the relevant `ERC1155TokenReceiver` hook(s) on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).
    @param _from    Source address
    @param _to      Target address
    @param _ids     IDs of each token type (order and length must match _values array)
    @param _values  Transfer amounts per token type (order and length must match _ids array)
    @param _data    Additional data with no specified format, MUST be sent unaltered in call to the `ERC1155TokenReceiver` hook(s) on `_to`
  */
  function safeBatchTransferFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _values, bytes memory _data) public virtual override {

    // MUST Throw on errors
    require(_to != address(0x0), "destination address must be non-zero.");
    require(_ids.length == _values.length, "_ids and _values array length must match.");
    require(_from == _msgSender() || isApprovedForAll(_from, _msgSender()), "Need operator approval for 3rd party transfers.");

    for (uint256 i = 0; i < _ids.length; ++i) {
      uint256 id = _ids[i];
      uint256 value = _values[i];

      // SafeMath will throw with insuficient funds _from
      // or if _id is not valid (balance will be 0)
      balances[id][_from] = balances[id][_from].sub(value);
      balances[id][_to]   = value.add(balances[id][_to]);
    }

    // Note: instead of the below batch versions of event and acceptance check you MAY have emitted a TransferSingle
    // event and a subsequent call to _doSafeTransferAcceptanceCheck in above loop for each balance change instead.
    // Or emitted a TransferSingle event for each in the loop and then the single _doSafeBatchTransferAcceptanceCheck below.
    // However it is implemented the balance changes and events MUST match when a check (i.e. calling an external contract) is done.

    // MUST emit event
    emit TransferBatch(_msgSender(), _from, _to, _ids, _values);

    // Now that the balances are updated and the events are emitted,
    // call onERC1155BatchReceived if the destination is a contract.
    if (_to.isContract()) {
      _doSafeBatchTransferAcceptanceCheck(_msgSender(), _from, _to, _ids, _values, _data);
    }
  }

  /**
    @notice Get the balance of an account's Tokens.
    @param _owner  The address of the token holder
    @param _id     ID of the Token
    @return        The _owner's balance of the Token type requested
    */
  function balanceOf(address _owner, uint256 _id) public view virtual override returns (uint256) {
    // The balance of any account can be calculated from the Transfer events history.
    // However, since we need to keep the balances to validate transfer request,
    // there is no extra cost to also privide a querry function.
    return balances[_id][_owner];
  }


  /**
    @notice Get the balance of multiple account/token pairs
    @param _owners The addresses of the token holders
    @param _ids    ID of the Tokens
    @return        The _owner's balance of the Token types requested (i.e. balance for each (owner, id) pair)
    */
  function balanceOfBatch(address[] memory _owners, uint256[] memory _ids) public view virtual override returns (uint256[] memory) {

    require(_owners.length == _ids.length);

    uint256[] memory balances_ = new uint256[](_owners.length);

    for (uint256 i = 0; i < _owners.length; ++i) {
      balances_[i] = balances[_ids[i]][_owners[i]];
    }

    return balances_;
  }

  /**
    * @dev See {IERC1155-setApprovalForAll}.
    */
  function setApprovalForAll(address operator, bool approved) public virtual override {
      require(_msgSender() != operator, "ERC1155: setting approval status for self");

      _operatorApprovals[_msgSender()][operator] = approved;
      emit ApprovalForAll(_msgSender(), operator, approved);
  }

  /**
    * @dev See {IERC1155-isApprovedForAll}.
    */
  function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
      return _operatorApprovals[account][operator];
  }

/////////////////////////////////////////// Internal //////////////////////////////////////////////

  function _doSafeTransferAcceptanceCheck(
    address operator,
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  )
    internal
  {
    if (to.isContract()) {
      try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
        if (response != IERC1155Receiver(to).onERC1155Received.selector) {
          revert("ERC1155: ERC1155Receiver rejected tokens");
        }
      } catch Error(string memory reason) {
        revert(reason);
      } catch {
        revert("ERC1155: transfer to non ERC1155Receiver implementer");
      }
    }
  }

  function _doSafeBatchTransferAcceptanceCheck(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  )
    internal
  {
    if (to.isContract()) {
      try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
        if (response != IERC1155Receiver(to).onERC1155BatchReceived.selector) {
          revert("ERC1155: ERC1155Receiver rejected tokens");
        }
      } catch Error(string memory reason) {
        revert(reason);
      } catch {
        revert("ERC1155: transfer to non ERC1155Receiver implementer");
      }
    }
  }

  function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4) {
    return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
  }
}