// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.13;

import {ERC721H} from "../abstract/ERC721H.sol";
import {NonReentrant} from "../abstract/NonReentrant.sol";
import {DelayedReveal} from "../abstract/DelayedReveal.sol";

import {HolographERC721Interface} from "../interface/HolographERC721Interface.sol";
import {HolographerInterface} from "../interface/HolographerInterface.sol";
import {HolographInterface} from "../interface/HolographInterface.sol";
import {ICustomERC721} from "../interface/ICustomERC721.sol";
import {IDropsPriceOracle} from "../drops/interface/IDropsPriceOracle.sol";
import {HolographTreasuryInterface} from "../interface/HolographTreasuryInterface.sol";

import {LazyMint} from "../extension/LazyMint.sol";

import {AddressMintDetails} from "../drops/struct/AddressMintDetails.sol";
import {CustomERC721Configuration} from "../struct/CustomERC721Configuration.sol";
import {CustomERC721Initializer} from "../struct/CustomERC721Initializer.sol";
import {SaleDetails} from "../drops/struct/SaleDetails.sol";
import {SalesConfiguration} from "../drops/struct/SalesConfiguration.sol";

import {Address} from "../drops/library/Address.sol";
import {MerkleProof} from "../drops/library/MerkleProof.sol";
import {Strings} from "./../drops/library/Strings.sol";

/**
 * @dev This contract subscribes to the following HolographERC721 events:
 *       - customContractURI
 *
 *       Do not enable or subscribe to any other events unless you modified the source code for them.
 */
contract CustomERC721 is NonReentrant, ERC721H, LazyMint, DelayedReveal, ICustomERC721 {
  using Strings for uint256;

  /**
   * CONTRACT VARIABLES
   * all variables, without custom storage slots, are defined here
   */

  /**
   * @dev Address of the price oracle proxy
   */
  IDropsPriceOracle public constant dropsPriceOracle = IDropsPriceOracle(0xeA7f4C52cbD4CF1036CdCa8B16AcA11f5b09cF6E);

  /**
   * @dev Internal reference used for minting incremental token ids.
   */
  uint224 private _currentTokenId;

  /// @dev Gas limit for transferring funds
  uint256 private constant STATIC_GAS_LIMIT = 210_000;

  /**
   * @notice Configuration for NFT minting contract storage
   */
  CustomERC721Configuration public config;

  /**
   * @notice Sales configuration
   */
  SalesConfiguration public salesConfig;

  /**
   * @dev Mapping for presale mint counts by address to allow public mint limit
   */
  mapping(address => uint256) public presaleMintsByAddress;

  /**
   * @dev Mapping for presale mint counts by address to allow public mint limit
   */
  mapping(address => uint256) public totalMintsByAddress;

  /**
   * CUSTOM ERRORS
   */

  /**
   * MODIFIERS
   */

  /**
   * @notice Allows user to mint tokens at a quantity
   */
  modifier canMintTokens(uint256 quantity) {
    // NOTE: NEED TO DECIDE IF WE WANT TO RESTRICT MINTING UNDER CERTAIN CONDITIONS
    _;
  }

  /**
   * @notice Presale active
   */
  modifier onlyPresaleActive() {
    if (!_presaleActive()) {
      revert Presale_Inactive();
    }

    _;
  }

  /**
   * @notice Public sale active
   */
  modifier onlyPublicSaleActive() {
    if (!_publicSaleActive()) {
      revert Sale_Inactive();
    }

    _;
  }

  /**
   * CONTRACT INITIALIZERS
   * init function is used instead of constructor
   */

  /**
   * @dev Constructor is left empty and init is used instead
   */
  constructor() {}

  /**
   * @notice Used internally to initialize the contract instead of through a constructor
   * @dev This function is called by the deployer/factory when creating a contract
   * @param initPayload abi encoded payload to use for contract initilaization
   */
  function init(bytes memory initPayload) external override returns (bytes4) {
    require(!_isInitialized(), "HOLOGRAPH: already initialized");

    CustomERC721Initializer memory initializer = abi.decode(initPayload, (CustomERC721Initializer));

    // Setup the owner role
    _setOwner(initializer.initialOwner);

    // to enable sourceExternalCall to work on init, we set holographer here since it's only set after init
    assembly {
      sstore(_holographerSlot, caller())
    }

    // Setup config variables
    config = CustomERC721Configuration({
      editionSize: initializer.editionSize,
      royaltyBPS: initializer.royaltyBPS,
      fundsRecipient: initializer.fundsRecipient
    });

    salesConfig = initializer.salesConfiguration;

    setStatus(1);

    return _init(initPayload);
  }

  /**
   * PUBLIC NON STATE CHANGING FUNCTIONS
   * static
   */

  /**
   * @notice Returns the version of the contract
   * @dev Used for contract versioning and validation
   * @return version of the contract
   */
  function version() external pure returns (uint32) {
    return 1;
  }

  function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
    return interfaceId == type(ICustomERC721).interfaceId;
  }

  /**
   * PUBLIC NON STATE CHANGING FUNCTIONS
   * dynamic
   */

  function owner() external view override(ERC721H, ICustomERC721) returns (address) {
    return _getOwner();
  }

  function isAdmin(address user) external view returns (bool) {
    return (_getOwner() == user);
  }

  /**
   * @notice Sale details
   * @return SaleDetails sale information details
   */
  function saleDetails() external view returns (SaleDetails memory) {
    return
      SaleDetails({
        publicSaleActive: _publicSaleActive(),
        presaleActive: _presaleActive(),
        publicSalePrice: salesConfig.publicSalePrice,
        publicSaleStart: salesConfig.publicSaleStart,
        publicSaleEnd: salesConfig.publicSaleEnd,
        presaleStart: salesConfig.presaleStart,
        presaleEnd: salesConfig.presaleEnd,
        presaleMerkleRoot: salesConfig.presaleMerkleRoot,
        totalMinted: _currentTokenId,
        maxSupply: config.editionSize,
        maxSalePurchasePerAddress: salesConfig.maxSalePurchasePerAddress
      });
  }

  /// @notice The Holograph fee is a flat fee for each mint in USD and is controlled by the treasury
  /// @dev Gets the flat Holograph protocol fee for a single mint in USD
  function getHolographFeeFromTreasury() public view returns (uint256) {
    address payable treasuryProxyAddress = payable(
      HolographInterface(HolographerInterface(holographer()).getHolograph()).getTreasury()
    );

    HolographTreasuryInterface treasury = HolographTreasuryInterface(treasuryProxyAddress);
    return treasury.getHolographMintFee();
  }

  /// @notice The Holograph fee is a flat fee for each mint in USD
  /// @dev Gets the Holograph protocol fee for amount of mints in USD
  function getHolographFeeUsd(uint256 quantity) public view returns (uint256 fee) {
    fee = getHolographFeeFromTreasury() * quantity;
  }

  /// @notice The Holograph fee is a flat fee for each mint in wei after conversion
  /// @dev Gets the Holograph protocol fee for amount of mints in wei
  function getHolographFeeWei(uint256 quantity) public view returns (uint256) {
    return _usdToWei(getHolographFeeFromTreasury() * quantity);
  }

  /**
   * @dev Number of NFTs the user has minted per address
   * @param minter to get counts for
   */
  function mintedPerAddress(address minter) external view returns (AddressMintDetails memory) {
    return
      AddressMintDetails({
        presaleMints: presaleMintsByAddress[minter],
        publicMints: totalMintsByAddress[minter] - presaleMintsByAddress[minter],
        totalMints: totalMintsByAddress[minter]
      });
  }

  /**
   * @notice Contract URI Getter, proxies to metadataRenderer
   * @return Contract URI
   */
  // function contractURI() external view returns (string memory) {
  //   return config.metadataRenderer.contractURI();
  // }

  /**
   * @notice Token URI Getter, proxies to metadataRenderer
   * @param _tokenId id of token to get URI for
   * @return Token URI
   */
  function tokenURI(uint256 _tokenId) public view returns (string memory) {
    (uint256 batchId, ) = _getBatchId(_tokenId);
    string memory batchUri = _getBaseURI(_tokenId);

    if (isEncryptedBatch(batchId)) {
      return string(abi.encodePacked(batchUri, "0"));
    } else {
      return string(abi.encodePacked(batchUri, _tokenId.toString()));
    }
  }

  /**
   * @notice Convert USD price to current price in native Ether units
   */
  function getNativePrice() external view returns (uint256) {
    return _usdToWei(salesConfig.publicSalePrice);
  }

  /**
   * @notice Returns the name of the token through the holographer entrypoint
   */
  function name() external view returns (string memory) {
    return HolographERC721Interface(holographer()).name();
  }

  /**
   * PUBLIC STATE CHANGING FUNCTIONS
   * available to all
   */

  function multicall(bytes[] memory data) public returns (bytes[] memory results) {
    results = new bytes[](data.length);
    for (uint256 i = 0; i < data.length; i++) {
      results[i] = Address.functionDelegateCall(address(this), abi.encodePacked(data[i], msgSender()));
    }
  }

  /*///////////////////////////////////////////////////////////////
                        Delayed reveal logic
    //////////////////////////////////////////////////////////////*/

  /**
   *  @notice       Lets an authorized address reveal a batch of delayed reveal NFTs.
   *
   *  @param _index The ID for the batch of delayed-reveal NFTs to reveal.
   *  @param _key   The key with which the base URI for the relevant batch of NFTs was encrypted.
   */
  function reveal(uint256 _index, bytes calldata _key) public virtual override returns (string memory revealedURI) {
    require(_canReveal(), "Not authorized");

    uint256 batchId = getBatchIdAtIndex(_index);
    revealedURI = getRevealURI(batchId, _key);

    _setEncryptedData(batchId, "");
    _setBaseURI(batchId, revealedURI);

    emit TokenURIRevealed(_index, revealedURI);
  }

  /**
   * @dev This allows the user to purchase/mint a edition at the given price in the contract.
   */
  function purchase(
    uint256 quantity
  ) external payable nonReentrant canMintTokens(quantity) onlyPublicSaleActive returns (uint256) {
    uint256 salePrice = _usdToWei(salesConfig.publicSalePrice);
    uint256 holographMintFeeUsd = getHolographFeeFromTreasury();
    uint256 holographMintFeeWei = _usdToWei(holographMintFeeUsd);

    if (msg.value < (salePrice + holographMintFeeWei) * quantity) {
      // The error will display what the correct price should be
      revert Purchase_WrongPrice((salesConfig.publicSalePrice + holographMintFeeUsd) * quantity);
    }
    uint256 remainder = msg.value - (salePrice * quantity);

    // If max purchase per address == 0 there is no limit.
    // Any other number, the per address mint limit is that.
    if (
      salesConfig.maxSalePurchasePerAddress != 0 &&
      totalMintsByAddress[msgSender()] + quantity - presaleMintsByAddress[msgSender()] >
      salesConfig.maxSalePurchasePerAddress
    ) {
      revert Purchase_TooManyForAddress();
    }

    // First mint the NFTs
    _mintNFTs(msgSender(), quantity);

    HolographERC721Interface H721 = HolographERC721Interface(holographer());
    uint256 chainPrepend = H721.sourceGetChainPrepend();
    uint256 firstMintedTokenId = (chainPrepend + uint256(_currentTokenId - quantity)) + 1;

    emit Sale({
      to: msgSender(),
      quantity: quantity,
      pricePerToken: salePrice,
      firstPurchasedTokenId: firstMintedTokenId
    });

    // Refund any overpayment
    if (remainder > 0) {
      msgSender().call{value: remainder, gas: gasleft() > STATIC_GAS_LIMIT ? STATIC_GAS_LIMIT : gasleft()}("");
    }

    return firstMintedTokenId;
  }

  /**
   * @notice Merkle-tree based presale purchase function
   * @param quantity quantity to purchase
   * @param maxQuantity max quantity that can be purchased via merkle proof #
   * @param pricePerToken price that each token is purchased at
   * @param merkleProof proof for presale mint
   */
  function purchasePresale(
    uint256 quantity,
    uint256 maxQuantity,
    uint256 pricePerToken,
    bytes32[] calldata merkleProof
  ) external payable nonReentrant canMintTokens(quantity) onlyPresaleActive returns (uint256) {
    if (
      !MerkleProof.verify(
        merkleProof,
        salesConfig.presaleMerkleRoot,
        keccak256(
          // address, uint256, uint256
          abi.encode(msgSender(), maxQuantity, pricePerToken)
        )
      )
    ) {
      revert Presale_MerkleNotApproved();
    }

    uint256 weiPricePerToken = _usdToWei(pricePerToken);
    if (msg.value < weiPricePerToken * quantity) {
      revert Purchase_WrongPrice(pricePerToken * quantity);
    }
    uint256 remainder = msg.value - (weiPricePerToken * quantity);

    presaleMintsByAddress[msgSender()] += quantity;
    if (presaleMintsByAddress[msgSender()] > maxQuantity) {
      revert Presale_TooManyForAddress();
    }

    // First mint the NFTs
    _mintNFTs(msgSender(), quantity);

    HolographERC721Interface H721 = HolographERC721Interface(holographer());
    uint256 chainPrepend = H721.sourceGetChainPrepend();
    uint256 firstMintedTokenId = (chainPrepend + uint256(_currentTokenId - quantity)) + 1;

    emit Sale({
      to: msgSender(),
      quantity: quantity,
      pricePerToken: weiPricePerToken,
      firstPurchasedTokenId: firstMintedTokenId
    });

    // Refund any overpayment
    if (remainder > 0) {
      msgSender().call{value: remainder, gas: gasleft() > STATIC_GAS_LIMIT ? STATIC_GAS_LIMIT : gasleft()}("");
    }

    return firstMintedTokenId;
  }

  /**
   * PUBLIC STATE CHANGING FUNCTIONS
   * admin only
   */

  /**
   *  We override the `lazyMint` function, and use the `_data` parameter for storing encrypted metadata
   *  for 'delayed reveal' NFTs.
   */
  function lazyMint(
    uint256 _amount,
    string calldata _baseURIForTokens,
    bytes calldata _data
  ) public override onlyOwner returns (uint256 batchId) {
    if (_data.length > 0) {
      (bytes memory encryptedURI, bytes32 provenanceHash) = abi.decode(_data, (bytes, bytes32));
      if (encryptedURI.length != 0 && provenanceHash != "") {
        _setEncryptedData(nextTokenIdToLazyMint + _amount, _data);
      }
    }

    return super.lazyMint(_amount, _baseURIForTokens, _data);
  }

  /**
   * @notice Admin mint tokens to a recipient for free
   * @param recipient recipient to mint to
   * @param quantity quantity to mint
   */
  function adminMint(address recipient, uint256 quantity) external onlyOwner canMintTokens(quantity) returns (uint256) {
    _mintNFTs(recipient, quantity);

    return _currentTokenId;
  }

  /**
   * @dev Mints multiple editions to the given list of addresses.
   * @dev TODO: Double chFeck if we need to use arrays for encryptedBaseUris and dataArray
   * @param recipients list of addresses to send the newly minted editions to
   */
  function adminMintAirdrop(
    address[] calldata recipients
  ) external onlyOwner canMintTokens(recipients.length) returns (uint256) {
    unchecked {
      for (uint256 i = 0; i != recipients.length; i++) {
        _mintNFTs(recipients[i], 1);
      }
    }

    return _currentTokenId;
  }

  /**
   * @dev This sets the sales configuration
   * @param publicSalePrice New public sale price
   * @param maxSalePurchasePerAddress Max # of purchases (public) per address allowed
   * @param publicSaleStart unix timestamp when the public sale starts
   * @param publicSaleEnd unix timestamp when the public sale ends (set to 0 to disable)
   * @param presaleStart unix timestamp when the presale starts
   * @param presaleEnd unix timestamp when the presale ends
   * @param presaleMerkleRoot merkle root for the presale information
   */
  function setSaleConfiguration(
    uint104 publicSalePrice,
    uint32 maxSalePurchasePerAddress,
    uint64 publicSaleStart,
    uint64 publicSaleEnd,
    uint64 presaleStart,
    uint64 presaleEnd,
    bytes32 presaleMerkleRoot
  ) external onlyOwner {
    salesConfig.publicSalePrice = publicSalePrice;
    salesConfig.maxSalePurchasePerAddress = maxSalePurchasePerAddress;
    salesConfig.publicSaleStart = publicSaleStart;
    salesConfig.publicSaleEnd = publicSaleEnd;
    salesConfig.presaleStart = presaleStart;
    salesConfig.presaleEnd = presaleEnd;
    salesConfig.presaleMerkleRoot = presaleMerkleRoot;

    emit SalesConfigChanged(msgSender());
  }

  /**
   * @notice Set a different funds recipient
   * @param newRecipientAddress new funds recipient address
   */
  function setFundsRecipient(address payable newRecipientAddress) external onlyOwner {
    if (newRecipientAddress == address(0)) {
      revert("Funds Recipient cannot be 0 address");
    }
    config.fundsRecipient = newRecipientAddress;
    emit FundsRecipientChanged(newRecipientAddress, msgSender());
  }

  /**
   * @notice This withdraws native tokens from the contract to the contract owner.
   */
  function withdraw() external override nonReentrant {
    if (config.fundsRecipient == address(0)) {
      revert("Funds Recipient address not set");
    }
    address sender = msgSender();

    // Get the contract balance
    uint256 funds = address(this).balance;

    // Check if withdraw is allowed for sender
    if (sender != config.fundsRecipient && sender != _getOwner()) {
      revert Access_WithdrawNotAllowed();
    }

    // Payout recipient
    (bool successFunds, ) = config.fundsRecipient.call{value: funds, gas: STATIC_GAS_LIMIT}("");
    if (!successFunds) {
      revert Withdraw_FundsSendFailure();
    }

    // Emit event for indexing
    emit FundsWithdrawn(sender, config.fundsRecipient, funds);
  }

  /**
   * @notice Admin function to finalize and open edition sale
   */
  function finalizeOpenEdition() external onlyOwner {
    if (config.editionSize != type(uint64).max) {
      revert Admin_UnableToFinalizeNotOpenEdition();
    }

    config.editionSize = uint64(_currentTokenId);
    emit OpenMintFinalized(msgSender(), config.editionSize);
  }

  /**
   * INTERNAL FUNCTIONS
   * non state changing
   */

  function _presaleActive() internal view returns (bool) {
    return salesConfig.presaleStart <= block.timestamp && salesConfig.presaleEnd > block.timestamp;
  }

  function _publicSaleActive() internal view returns (bool) {
    return salesConfig.publicSaleStart <= block.timestamp && salesConfig.publicSaleEnd > block.timestamp;
  }

  function _usdToWei(uint256 amount) internal view returns (uint256 weiAmount) {
    if (amount == 0) {
      return 0;
    }
    weiAmount = dropsPriceOracle.convertUsdToWei(amount);
  }

  /**
   * @dev Checks whether NFTs can be lazy minted in the given execution context.
   *      TODO: Validate/check if the logic is working for lazy minting
   * @return Whether NFTs can be lazy minted.
   */
  function _canLazyMint() internal view override returns (bool) {
    return _publicSaleActive() || _presaleActive();
  }

  /**
   * INTERNAL FUNCTIONS
   * state changing
   */

  /// @dev Checks whether NFTs can be revealed in the given execution context.
  function _canReveal() internal view virtual returns (bool) {
    return msg.sender == _getOwner();
  }

  function _mintNFTs(address recipient, uint256 quantity) internal {
    HolographERC721Interface H721 = HolographERC721Interface(holographer());
    uint256 chainPrepend = H721.sourceGetChainPrepend();
    uint224 tokenId = 0;
    for (uint256 i = 0; i != quantity; ) {
      unchecked {
        _currentTokenId += 1;
      }
      while (
        H721.exists(chainPrepend + uint256(_currentTokenId)) || H721.burned(chainPrepend + uint256(_currentTokenId))
      ) {
        unchecked {
          _currentTokenId += 1;
        }
      }
      tokenId = _currentTokenId;
      H721.sourceMint(recipient, tokenId);

      uint256 id = chainPrepend + uint256(tokenId);
      emit NFTMinted(recipient, tokenId, id);

      unchecked {
        i++;
      }
    }
  }

  fallback() external payable override {
    assembly {
      // Allocate memory for the error message
      let errorMsg := mload(0x40)

      // Error message: "Function not found", properly padded with zeroes
      mstore(errorMsg, 0x46756e6374696f6e206e6f7420666f756e640000000000000000000000000000)

      // Revert with the error message
      revert(errorMsg, 20) // 20 is the length of the error message in bytes
    }
  }
}
