const expect = require("chai").expect;

const Escrow = artifacts.require("Escrow");
const Tokens = artifacts.require("Tokens");

contract("Escrow - General Tests", async accounts => {
  
  let instance, tokensInstance, ERC20_TOKEN_ID, CONVERSION_RATE;

  const offer1Title = "Offer 1", offer1Price = web3.utils.toBN(20);
  const offer2Title = "Offer 2", offer2Price = web3.utils.toBN(10);

  beforeEach(async () => { 
    // Create contract instances before each test
    instance = await Escrow.deployed();
    tokensInstance = await Tokens.deployed();

    // ERC20 token has an ID defined in the contract (retrieve it)
    // Conversion rate is defined in the contract (retrieve it)
    CONVERSION_RATE = await tokensInstance.CONVERSION_RATE(); // Get contract conversion rate
    ERC20_TOKEN_ID = await tokensInstance.ERC20_TOKEN_ID(); // Get ERC20 Token ID
  });

  it("credit account with tokens", async () => {

    // Credit accounts[0] with 100 ERC20 Token
    // Credit accounts[1] with 100 ERC20 Token

    try {
      const _amount = 10; // Amount of ETH (credit is payable)

      await instance.credit({ value: _amount });

      const ERC20TokenBalance0 = await tokensInstance.balanceOf(accounts[0], ERC20_TOKEN_ID.toNumber()); // ERC20 Token balance for account 0
      expect(ERC20TokenBalance0.toNumber()).to.equal(_amount * CONVERSION_RATE.toNumber(), "account[0] should receive newly minted ERC20 tokens");

      await instance.credit({ from: accounts[1], value: _amount });

      const ERC20TokenBalance1 = await tokensInstance.balanceOf(accounts[1], ERC20_TOKEN_ID.toNumber()); // ERC20 Token balance for account 1
      expect(ERC20TokenBalance1.toNumber()).to.equal(_amount * CONVERSION_RATE.toNumber(), "account[1] should receive newly minted ERC20 tokens");
    } catch (error) {
      console.error(error);
      assert.fail("One or more errors occured.");
    }
  });

  it("create new offer(s)", async () => {

    // Create 2 offers with accounts[0]

    try {
      await instance.createOffer(offer1Title, offer1Price); // Create new offer 1 with default account
      await instance.createOffer(offer2Title, offer2Price); // Create new offer 2 with default account

      await tokensInstance.setApprovalForAll(instance.address, true); // Allow contract to manage your offer during escrow

      // This should be returned by the initial createOffer call, but had issues with it not being "view"
      const offerId = await instance.generateOfferId(accounts[0], offer1Title); 

      const offerExists = await tokensInstance.exists(offerId);
      expect(offerExists).to.equal(true, "Newly created offer should exist");

      const nonFungableBalance = await tokensInstance.balanceOf(accounts[0], offerId);
      expect(nonFungableBalance.toNumber()).to.equal(1, "NonFungable balance should be 1");
      
      const offerOwner = await tokensInstance.ownerOfNonFungible(offerId);
      expect(offerOwner).to.equal(accounts[0], "Offer owner should be account 0");

      const offerData = await instance.getOffer(offerId);
      expect(offerData[0]).to.equal(offer1Title, "Offer title should match");
      expect(offerData[1].toNumber()).to.equal(offer1Price.toNumber(), "Offer price should match");
    } catch (error) {
      console.error(error);
      assert.fail("One or more errors occured.");
    }
  });

  it("fail to create an offer with existing name & seller", async () => {

    // Offer with `offer1Title` was created in previous step and the state was not reset
    // Attempting to create a new offer with the same title and account should fail
    // This logic should be more sophisticated in production 

    try {
      const offerId = await instance.generateOfferId(accounts[0], offer1Title);
      const existingOffer = await tokensInstance.exists(offerId);

      expect(existingOffer).to.equal(true, "Offer1 should exist");

      try {
        await instance.createOffer(offer1Title, offer1Price);
      } catch (error) {
        expect(error.reason).to.equal("Tokens: NFT must not exist when minting");
      }
    } catch (error) {
      console.error(error);
      assert.fail("One or more errors occured.");
    }
  });

  it("place order on existing offer1", async () => {

    // Offer with `offer1Title` was created in previous step and the state was not reset
    // An order can be placed with an account that has enough $ERC20 (account[0] - default)

    try {
      const initialERC20Balance = await tokensInstance.balanceOf(accounts[1], ERC20_TOKEN_ID.toNumber()); // Fetch $ERC20 balance for account[1] before placing order

      const offerId = await instance.generateOfferId(accounts[0], offer1Title);
      const existingOffer = await tokensInstance.exists(offerId);

      expect(existingOffer).to.equal(true, "Offer1 should exist before placing the order");

      const offerData = await instance.getOffer(offerId); // Fetch offer data for validation

      await tokensInstance.setApprovalForAll(instance.address, true, { from: accounts[1] }); // Allow contract to manage your offer during escrow
      await instance.placeOrder(offerId, { // Place order from account[1]
        from: accounts[1]
      });

      const orderId = await instance.generateOrderId(accounts[1], offerId); 
      const orderExists = await tokensInstance.exists(orderId);
      expect(orderExists).to.equal(true, "Newly created order should exist");

      const orderData = await instance.getOrder(orderId);
      expect(orderData[1].toNumber()).to.equal(offerData[1].toNumber(), "Offer price and order amount should equal");
      expect(orderData[2].toString()).to.equal(offerId.toString(), "Offer id and order offer id should equal");

      const afterERC20Balance = await tokensInstance.balanceOf(accounts[1], ERC20_TOKEN_ID.toNumber()); // Fetch $ERC20 balance for account[1] after order placed
      expect(afterERC20Balance.toNumber()).to.equal(initialERC20Balance.toNumber() - orderData[1].toNumber(), "$ERC20 amount for account[1] should reflect order"); // Validate $ERC20 amount has been transfered
    } catch (error) {
      console.error(error);
      assert.fail("One or more errors occured.");
    }
  });

  it("fail to place order on the same offer with same account", async () => {

    // An order was placed by accounts[1] on `offer1` in the previous step
    // The same account should fail when trying to place the same order again

    try {
      const offerId = await instance.generateOfferId(accounts[0], offer1Title);
      const existingOffer = await tokensInstance.exists(offerId);

      expect(existingOffer).to.equal(true, "Offer1 should exist");

      try {
        await instance.placeOrder(offerId, { // Place order from account[1]
          from: accounts[1]
        });
      } catch (error) {
        expect(error.reason).to.equal("Tokens: NFT must not exist when minting");
      }
    } catch (error) {
      console.error(error);
      assert.fail("One or more errors occured.");
    }
  });
  
  it("complete order as the buyer (account[1])", async () => {

    // Complete the order 
    // Transfer payment to seller
    // Transfer offer ownership to buyer

    try {
      const initialERC20Balance = await tokensInstance.balanceOf(accounts[0], ERC20_TOKEN_ID.toNumber()); // Fetch $ERC20 balance for account[0] (seller) before completing order 
      const offerId = await instance.generateOfferId(accounts[0], offer1Title);

      const orderId = await instance.generateOrderId(accounts[1], offerId); 
      const orderExists = await tokensInstance.exists(orderId);
      expect(orderExists).to.equal(true, "Order should exist");

      const orderData = await instance.getOrder(orderId); // Fetch order data for validation

      const offerOwner = await tokensInstance.ownerOfNonFungible(offerId);
      expect(offerOwner).to.equal(accounts[0], "Offer owner should be account 0");

      await instance.completeOrder(orderId, { // Complete order from account[1]
        from: accounts[1]
      });

      const newOfferOwner = await tokensInstance.ownerOfNonFungible(offerId); // After order is completed, offer owner is the buyer
      expect(newOfferOwner).to.equal(accounts[1], "Offer owner should be account 1");

      const afterERC20Balance = await tokensInstance.balanceOf(accounts[0], ERC20_TOKEN_ID.toNumber()); // Fetch $ERC20 balance for account[0] after order placed
      expect(afterERC20Balance.toNumber()).to.equal(initialERC20Balance.toNumber() + orderData[1].toNumber(), "$ERC20 amount for account[0] (seller) should reflect order"); // Validate $ERC20 amount has been transfered
    } catch (error) {
      console.error(error);
      assert.fail("One or more errors occured.");
    }
  });

  it("complain order as the buyer (account[1])", async () => {

    // Complain order 
    // Reimburse buyer 

    try {
      const offerId = await instance.generateOfferId(accounts[0], offer2Title);

      await instance.placeOrder(offerId, { // Place new order from account[1] for Offer 2
        from: accounts[1]
      });

      const initialERC20Balance = await tokensInstance.balanceOf(accounts[1], ERC20_TOKEN_ID.toNumber()); // Fetch $ERC20 balance for account[0] (seller) before complaining order 
      const orderId = await instance.generateOrderId(accounts[1], offerId); 
      const orderExists = await tokensInstance.exists(orderId);
      expect(orderExists).to.equal(true, "Order should exist");

      const orderData = await instance.getOrder(orderId); // Fetch order data for validation

      await instance.complain(orderId, { // Place order from account[1]
        from: accounts[1]
      });

      const afterERC20Balance = await tokensInstance.balanceOf(accounts[1], ERC20_TOKEN_ID.toNumber()); // Fetch $ERC20 balance for account[0] after order placed
      expect(afterERC20Balance.toNumber()).to.equal(initialERC20Balance.toNumber() + orderData[1].toNumber(), "$ERC20 amount for account[0] (seller) should reflect order"); // Validate $ERC20 amount has been transfered
    } catch (error) {
      console.error(error);
      assert.fail("One or more errors occured.");
    }
  });
})