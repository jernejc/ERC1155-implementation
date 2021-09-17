
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./Tokens.sol";

/**
 *
 * @dev Basic Implementation of escrow logic
 *
 */
contract Escrow is Context, AccessControl {

  struct Offer { // Represents an Offer for sale
    string title;
    uint256 price;
  }

  mapping(uint256 => Offer) offers;

  struct Order { // Represents an order for Offer
    address buyer;
    uint256 amount;
    uint256 offer_id;
  }

  mapping(uint256 => Order) orders;

  // Used to interact with the tokens contract
  Tokens public TokensContract;

  /**
    * @dev Contract Constructor
    * 
    * Requirements:
        *
        * - must provider Tokens contract address
        * 
    *
    */

  constructor(address tokensAddress) public {
    require(
      tokensAddress != address(0) && tokensAddress != address(this),
      "Escrow: Must have a valid contract address"
    );

    TokensContract = Tokens(tokensAddress);
  }

  /**
   * @dev Credit $ERC20 with which you can participate in the escrow  
   * Costs ETH to credit, conversion rate is fixed
   * 
   * Requirements:
      *
      * - you have to credit at least 1 $ERC20
      * 
   *
   */

  function credit() public payable {
    require(msg.value * TokensContract.CONVERSION_RATE() > 1, "Escrow: You must credit at least one $ERC20");

    TokensContract.mintFungible(_msgSender(), TokensContract.ERC20_TOKEN_ID(), msg.value * TokensContract.CONVERSION_RATE()); // Mint ERC20 tokens to payable address
  }

  /**
   * @dev Offer item for sale
   *
   * Requirements:
      *
      * - offer `title` must be unique
      * - `price` must be greater than 0
      * 
   *
   * @return uint256 of the expiration time
   */

  function createOffer(string memory title, uint256 price) 
    public
    returns (uint256)
   {
    require(price > 0, "Escrow: Offer price must be greater than 0.");

    uint256 offer_id = generateOfferId(_msgSender(), title);

    TokensContract.mintNonFungible(_msgSender(), offer_id); // Mint NFT that represents this offer to the sender (will fail if exists)

    offers[offer_id] = Offer({
      title: title,
      price: price
    });

    //emit OfferStatus()
    return offer_id;
  }

  /**
  * @dev Get offer data for given id
  * @return offer title 
  * @return uint256 offer price
  */

  function getOffer(uint256 offer_id)
    external
    view
    returns (
      string memory,
      uint256
    )
  {
    require(
      TokensContract.exists(offer_id), // Solidity will return 0 if there is no existing bid
      "Escrow: No offer for given id"
    );

    Offer memory offer = _getOffer(offer_id);

    return (offer.title, offer.price);
  }

  /**
   * @dev Place an order for existing offer
   *
   * Requirements:
      *
      * - `offer_id` must exist
      * - buyer must have enough $ERC20
   *
   */

  function placeOrder(uint256 offer_id) public {
    require(TokensContract.exists(offer_id), "Escrow: Offer with given `offer_id` must exist.");

    Offer memory offer = offers[offer_id];

    require(TokensContract.balanceOf(_msgSender(), TokensContract.ERC20_TOKEN_ID()) >= offer.price, "Escrow: Buyer must have sufficient $ERC20 for order.");

    TokensContract.safeTransferFrom(_msgSender(), address(this), TokensContract.ERC20_TOKEN_ID(), offer.price, ""); // Transfer buyer funds to contract

    uint256 order_id = generateOrderId(_msgSender(), offer_id); // Generate new order_id

    TokensContract.mintNonFungible(TokensContract.ownerOfNonFungible(offer_id), order_id); // Mint NFT that represents this order to the owner of the offer (will fail if exists))

    orders[order_id] = Order({
      buyer: _msgSender(),
      amount: offer.price,
      offer_id: offer_id
    });
  }

  /**
  * @dev Get order for offer
  * @return buyer address
  * @return order amount
  * @return offer_id
  */

  function getOrder(uint256 order_id)
    external
    view
    returns (
      address,
      uint256,
      uint256
    )
  {
    require(
      TokensContract.exists(order_id), // Solidity will return 0 if there is no existing bid
      "Escrow: No order for given id"
    );

    Order memory order = _getOrder(order_id);

    return (order.buyer, order.amount, order.offer_id);
  }

  /**
   * @dev Refund the order if it's not fulfilled  
   *
   * Requirements:
      *
      * - `order_id` must exist
      * - only buyer can complain
      * 
   *
   */

  function complain(uint256 order_id) public {
    require(TokensContract.exists(order_id), "Escrow: Order with given `order_id` must exist.");

    Order memory order = orders[order_id];

    require(_msgSender() == order.buyer, "Escrow: Only buyer can complain an order.");

    // Refund $ERC20 to buyer
    TokensContract.safeTransferFrom(address(this), _msgSender(), TokensContract.ERC20_TOKEN_ID(), order.amount, ""); // Refund buyer when he files a complaint
  }

  /**
   * @dev Pay seller once the order is completed  
   *
      * Requirements:
      *
      * - `order_id`
      * - only buyer can complete
      * 
   *
   */

  function completeOrder(uint256 order_id) public {
    require(TokensContract.exists(order_id), "Escrow: Order with given `order_id` must exist.");

    Order memory order = orders[order_id];

    require(_msgSender() == order.buyer, "Escrow: Only buyer can complete an order");

    // Transfer $ERC20 to offer owner
    TokensContract.safeTransferFrom(address(this), TokensContract.ownerOfNonFungible(order.offer_id), TokensContract.ERC20_TOKEN_ID(), order.amount, ""); // Pay seller when buyer completes the order

    // Transfer Offer NFT to buyer
    TokensContract.safeTransferFrom(TokensContract.ownerOfNonFungible(order.offer_id), order.buyer, order.offer_id, 1, ""); // Transfer offer NFT ownership to buyer
  }

  /**
    * @dev Get offer for ID
    * @return Offer
    */
  function _getOffer(uint256 offer_id) private view returns (Offer memory) {
    return offers[offer_id];
  }

  /**
    * @dev Get order for ID
    * @return Order
    */
  function _getOrder(uint256 order_id) private view returns (Order memory) {
    return orders[order_id];
  }
  
  /**
    * @dev Generate Offer ID hash
    * Should have more constraints and validation in production
    * @return uint256
    */
  function generateOfferId(address seller, string memory title) public view returns (uint256) {
    return uint256(keccak256(abi.encode(seller, title)));
  }
  
  /**
    * @dev Generate Order ID hash
    * Should have more constraints and validation in production
    * @return uint256
    */
  function generateOrderId(address buyer, uint256 offer_id) public view returns (uint256) {
    return uint256(buyer) | offer_id;
  }

  /**
    * @dev Contract must be an ERC1155 Receiver to handle the escrow
    * @return bytes4
    */
  function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4) {
    return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
  }
}
