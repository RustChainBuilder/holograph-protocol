// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Constants, ErrorConstants} from "../utils/Constants.sol";
import {ERC721H} from "../../../src/abstract/ERC721H.sol";
import {Holographer} from "../../../src/enforcer/Holographer.sol";
import {HolographLegacyERC721} from "../../../src/token/HolographLegacyERC721.sol";
import {MockExternalCall} from "../../../src/mock/MockExternalCall.sol";

/**
 * @title Testing the ERC721H
 * @notice Suite of unit tests for the ERC721H contract
 * @dev Translation of a suite of Hardhat tests found in test/19_ERC721H_tests.ts
 */
contract ERC721HTests is Test {
  MockExternalCall mockExternalCall;
  ERC721H erc721h;
  HolographLegacyERC721 holographLegacyERC721;
  bytes initCode;
  uint256 localHostFork;
  string LOCALHOST_RPC_URL = vm.envString("LOCALHOST_RPC_URL");
  address deployer = vm.addr(Constants.getPKDeployer());
  address alice = vm.addr(1);

  /**
   * @notice Sets up the test environment
   * @dev This function sets up the test environment by creating a local fork of the network,
   * electing the fork, and initializing the ERC721H contract and the MockExternalCall contract.
   */
  function setUp() public {
    localHostFork = vm.createFork(LOCALHOST_RPC_URL);
    vm.selectFork(localHostFork);
    erc721h = ERC721H(payable(Constants.getSampleERC721()));
    holographLegacyERC721 = new HolographLegacyERC721();
    mockExternalCall = new MockExternalCall();
  }

  /* -------------------------------------------------------------------------- */
  /*                                   init()                                   */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the init function reverts when called twice
   * @dev This test verifies that the init function of the ERC721 contract reverts when called twice.
   * Refers to the hardhat test with the description 'should fail be initialized twice'
   */
  function testInit() public {
    vm.expectRevert(bytes(ErrorConstants.HOLOGRAPHER_ALREADY_INITIALIZED_ERROR_MSG));
    vm.prank(deployer);
    erc721h.init(abi.encode(deployer));
  }

  /* -------------------------------------------------------------------------- */
  /*                                   owner()                                  */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the owner function returns the correct owner
   * @dev This test verifies that the owner function of the ERC721 contract returns the correct owner address.
   * Refers to the hardhat test with the description 'should return the correct owner address'
   */
  function testReturnCorrectOwner() public {
    vm.prank(deployer);
    address ownerAddress = erc721h.owner();
    assertEq(ownerAddress, deployer);
  }

  /**
   * @notice Tests that the owner function does not return the wrong address
   * @dev This test verifies that the owner function of the ERC721 contract does not return the wrong address.
   * Refers to the hardhat test with the description 'should fail when comparing to wrong address'
   */
  function testComparingToWrongAddressFail() public {
    vm.prank(alice);
    address ownerAddress = erc721h.owner();
    assertNotEq(ownerAddress, alice);
  }

  /**
   * @notice Tests that an external contract can call the owner function
   * @dev This test verifies that an external contract can successfully call the owner function of the
   * ERC721 contract. If unsuccessful the test would revert.
   * Refers to the hardhat test with the description 'should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnOwner() public {
    bytes memory encodeSignature = abi.encodeWithSignature("owner()");
    vm.prank(deployer);
    mockExternalCall.callExternalFn(address(erc721h), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                                   isOwner                                  */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Tests that an external contract can call the isOwner function
   * @dev This test verifies that an external contract can successfully call the isOwner function of the
   * ERC721 contract. If unsuccessful the test would revert.
   * Refers to the hardhat test with the description 'should allow external contract to call fn',
   */
  function testAllowExternalContractToCallFnIsOwner() public {
    bytes memory encodeSignature = abi.encodeWithSignature("isOwner()");
    vm.prank(deployer);
    mockExternalCall.callExternalFn(address(erc721h), encodeSignature);
  }

  /**
   * @notice Tests that an external contract can call the isOwner function with parameters
   * @dev This test verifies that an external contract can successfully call the isOwner function of the
   * ERC721 contract with parameters. If unsuccessful the test would revert.
   * Refers to the hardhat test with the description 'should allow external contract to call fn with params'
   */
  function testAllowExternalContractToCallFnWithParams() public {
    bytes memory encodeSignature = abi.encodeWithSignature("isOwner(address)", deployer);
    vm.prank(deployer);
    mockExternalCall.callExternalFn(address(erc721h), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                              supportsInterface                             */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the supportsInterface function returns true for a valid interface
   * @dev This test verifies that the supportsInterface function of the ERC721 contract returns true for a valid interface.
   * Refers to the hardhat test with the description 'should return true if interface is valid'
   */
  function testReturnTrueIfInterfaceIsValid() public {
    bytes memory validInterface = abi.encodeWithSignature("totalSupply()");
    vm.prank(deployer);
    assertTrue(erc721h.supportsInterface(bytes4(validInterface)));
  }

  /**
   * @notice Tests that the supportsInterface function returns false for an invalid interface
   * @dev This test verifies that the supportsInterface function of the ERC721 contract returns false for an invalid interface.
   * Refers to the hardhat test with the description 'should return false if interface is invalid'
   */
  function testReturnFalseIfInterfaceIsInvalid() public {
    bytes memory invalidInterface = abi.encodeWithSignature("invalidMethod(address,address,uint256,bytes)");
    vm.prank(deployer);
    assertFalse(erc721h.supportsInterface(bytes4(invalidInterface)));
  }

  /**
   * @notice Tests that an external contract can call the supportsInterface function
   * @dev This test verifies that an external contract can successfully call the supportsInterface function of
   * the ERC721 contract. If unsuccessful the test would revert.
   * Refers to the hardhat test with the description 'should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnSupportInterfaces() public {
    bytes memory validInterface = abi.encodeWithSignature("totalSupply()");
    bytes memory encodeSignature = abi.encodeWithSignature("supportsInterface(bytes4)", bytes4(validInterface));
    vm.prank(deployer);
    mockExternalCall.callExternalFn(address(erc721h), encodeSignature);
  }

  /* -------------------------------------------------------------------------- */
  /*                                holographer                                */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the _holographer function is internal
   * @dev This test verifies that the holographer function of the ERC721 contract is internal and cannot be called.
   * Refers to the hardhat test with the description 'is internal function'
   */
  function testHolographerIsInternalFunction() public {
    bytes memory encodedFunctionData = abi.encodeWithSignature("holographer()");
    (bool success, bytes memory data) = address(holographLegacyERC721).call(encodedFunctionData);
    assertFalse(success);
  }

  /* -------------------------------------------------------------------------- */
  /*                                msgSender()                                */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the _msgSender function is internal
   * @dev This test verifies that the msgSender function of the ERC721 contract is internal and cannot be called.
   * Refers to the hardhat test with the description 'is internal function'
   */
  function testMsgSenderIsInternalFunction() public {
    bytes memory encodedFunctionData = abi.encodeWithSignature("msgSender()");
    (bool success, bytes memory data) = address(holographLegacyERC721).call(encodedFunctionData);
    assertFalse(success);
  }

  /* -------------------------------------------------------------------------- */
  /*                                  _getOwner                                 */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the _getOwner function is internal
   * @dev This test verifies that the _getOwner function of the ERC721 contract is internal and cannot be called.
   * Refers to the hardhat test with the description 'is internal function'
   */
  function testGetOwnerIsInternalFunction() public {
    bytes memory encodedFunctionData = abi.encodeWithSignature("_getOwner()");
    (bool success, bytes memory data) = address(holographLegacyERC721).call(encodedFunctionData);
    assertFalse(success);
  }

  /* -------------------------------------------------------------------------- */
  /*                                  _setOwner                                 */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the _setOwner function is internal
   * @dev This test verifies that the _setOwner function of the ERC721 contract is internal and cannot be called.
   * Refers to the hardhat test with the description 'is internal function'
   */
  function testSetOwnerIsInternalFunction() public {
    bytes memory encodedFunctionData = abi.encodeWithSignature("_setOwner()");
    (bool success, bytes memory data) = address(holographLegacyERC721).call(encodedFunctionData);
    assertFalse(success);
  }
}
