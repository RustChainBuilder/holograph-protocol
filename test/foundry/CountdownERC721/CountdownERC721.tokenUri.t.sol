// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ICustomERC721Errors} from "test/foundry/interface/ICustomERC721Errors.sol";
import {CountdownERC721Fixture} from "test/foundry/fixtures/CountdownERC721Fixture.t.sol";

import {Vm} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {DEFAULT_BASE_URI, DEFAULT_PLACEHOLDER_URI, DEFAULT_ENCRYPT_DECRYPT_KEY, DEFAULT_MAX_SUPPLY} from "test/foundry/CountdownERC721/utils/Constants.sol";

import {ICountdownERC721} from "src/interface/ICountdownERC721.sol";
import {Strings} from "src/library/Strings.sol";

contract CountdownERC721PurchaseTest is CountdownERC721Fixture, ICustomERC721Errors {
  using Strings for uint256;

  constructor() {}

  function setUp() public override {
    super.setUp();
  }

  function test_tokenUri() public setupTestCountdownErc721(DEFAULT_MAX_SUPPLY) setUpPurchase {
    /* -------------------------------- Purchase -------------------------------- */
    vm.prank(address(TEST_ACCOUNT));
    vm.deal(address(TEST_ACCOUNT), totalCost);
    uint256 tokenId = countdownErc721.purchase{value: totalCost}(1);

    // First token ID is this long number due to the chain id prefix
    require(erc721Enforcer.ownerOf(tokenId) == address(TEST_ACCOUNT), "Incorrect owner for newly minted token");
    assertEq(address(sourceContractAddress).balance, nativePrice);

    /* ----------------------------- Check tokenURI ----------------------------- */

    // TokenURI call should revert because the metadata of the batch has not been set yet (need to call lazyMint before)
    vm.expectRevert(abi.encodeWithSelector(BatchMintInvalidTokenId.selector, tokenId));
    countdownErc721.tokenURI(tokenId);
    vm.expectRevert(abi.encodeWithSelector(BatchMintInvalidTokenId.selector, 0));
    countdownErc721.tokenURI(0);
  }
}
