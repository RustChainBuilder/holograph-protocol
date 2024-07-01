// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Constants, ErrorConstants} from "../utils/Constants.sol";
import {HelperDeploymentConfig} from "../utils/HelperDeploymentConfig.sol";
import {HelperSignEthMessage} from "../utils/HelperSignEthMessage.sol";
import {HolographERC20} from "../../../src/enforcer/HolographERC20.sol";
import {Holographer} from "../../../src/enforcer/Holographer.sol";
import {Holograph} from "../../../src/Holograph.sol";
import {ERC20} from "../../../src/interface/ERC20.sol";
import {Mock} from "../../../src/mock/Mock.sol";
import {HolographFactory} from "../../../src/HolographFactory.sol";
import {HolographRegistry} from "../../../src/HolographRegistry.sol";
import {DeploymentConfig} from "../../../src/struct/DeploymentConfig.sol";
import {Verification} from "../../../src/struct/Verification.sol";

/**
 * @title Testing the Holograph Factory
 * @notice Suite of unit tests for Holograph Factory contracts
 * @dev Translation of a suite of Hardhat tests found in test/11_holograph_factory_tests.ts
 */

contract HolographFactoryTest is Test {
  uint256 localHostFork;
  string LOCALHOST_RPC_URL = vm.envString("LOCALHOST_RPC_URL");

  HolographERC20 holographERC20;
  HolographRegistry holographRegistry;
  HolographFactory holographFactory;
  Holograph holograph;
  Mock mock;

  uint256 privateKeyDeployer = Constants.getPKDeployer();
  address deployer = vm.addr(privateKeyDeployer);
  address owner = vm.addr(1);
  address newOwner = vm.addr(2);
  address alice = vm.addr(3);
  bytes invalidSignature = Constants.EMPTY_BYTES;

  /**
   * @notice Sets up the environment for testing the Holograph Factory
   * @dev This function performs the following setup steps:
   * 1. Deploys a new instance of the `Mock` contract, pranking as the `deployer`.
   * 2. Creates a fork of the local host RPC URL and selects the forked chain.
   * 3. Retrieves instances of the `HolographRegistry`, `HolographFactory`, and `Holograph` contracts
   *    using the `Constants` contract and assigns them to the corresponding variables.
   */
  function setUp() public {
    vm.prank(deployer);
    mock = new Mock();

    localHostFork = vm.createFork(LOCALHOST_RPC_URL);
    vm.selectFork(localHostFork);
    holographRegistry = HolographRegistry(payable(Constants.getHolographRegistryProxy()));
    holographFactory = HolographFactory(payable(Constants.getHolographFactoryProxy()));
    holograph = Holograph(payable(Constants.getHolograph()));
  }

  /**
   * @notice Get the config to deploy the hToken ETH contract
   * @dev Get the deployment configuration and the hash of hTokenETH in chain 1 (localhost)
   */
  function getConfigHtokenETH() public view returns (DeploymentConfig memory, bytes32) {
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getHtokenEth(
      Constants.getHolographIdL1(),
      vm.getCode("hTokenProxy.sol:hTokenProxy"),
      bytes32(Constants.EMPTY_BYTES),
      true
    );

    bytes32 hashHtokenEth = HelperDeploymentConfig.getDeployConfigHash(deployConfig, deployer);
    return (deployConfig, hashHtokenEth);
  }

  /**
   * @notice Get the config to deploy the SampleERC721 contract
   * @dev Get the deployment configuration and the hash of SampleERC721 in chain 1 (localhost)
   */
  function getConfigERC721() public view returns (DeploymentConfig memory, bytes32) {
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getERC721(
      Constants.getHolographIdL1(),
      vm.getCode("SampleERC721.sol:SampleERC721"),
      Constants.EMPTY_BYTES32, // eventConfig,
      true
    );

    bytes32 hashSampleERC721 = HelperDeploymentConfig.getDeployConfigHash(deployConfig, deployer);
    return (deployConfig, hashSampleERC721);
  }

  /* -------------------------------------------------------------------------- */
  /*                                INIT Section                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the initialization of the HolographFactory contract
   * @dev This test checks that the `init` function of the Holograph Factory reverts  with
   * the `HOLOGRAPH: already initialized` error message when called multiple times.
   * Refers to the hardhat test with the description 'should fail if already initialized'
   */
  function testInitRevert() public {
    bytes memory init = abi.encode(Constants.getHolographFactory(), Constants.getHolographRegistry());
    vm.expectRevert(bytes(ErrorConstants.ALREADY_INITIALIZED_ERROR_MSG));
    holographFactory.init(abi.encode(address(deployer), address(holographERC20)));
  }

  /* -------------------------------------------------------------------------- */
  /*                    Deploy Holographable Contract Section                   */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the deployHolographableContract function Revert if the signature is invalid
   * @dev  This test checks that the `deployHolographableContract` function of the Holograph Factory
   * reverts with the `HOLOGRAPH: invalid signature` error message when the provided signature is invalid.
   * It first retrieves the deployment configuration and hash for the hToken ETH contract and generates
   * a new signature with an incorrect private key. Calls the `deployHolographableContract` function with
   * the invalid signature and expects the function to revert
   * Refers to the hardhat test with the description 'should fail with invalid signature if config is incorrect'
   */
  function testDeployRevertInvalidSignature() public {
    (DeploymentConfig memory deployConfig, bytes32 hashHtokenEth) = getConfigHtokenETH();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKeyDeployer,
      HelperSignEthMessage.toEthSignedMessageHash(hashHtokenEth)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    vm.expectRevert(bytes(ErrorConstants.INVALID_SIGNATURE_ERROR_MSG));
    vm.prank(deployer);
    holographFactory.deployHolographableContract(deployConfig, signature, owner);
  }

  /**
   * @notice Test the deployHolographableContract function Revert if the contract was already deployed
   * @dev This test checks that the `deployHolographableContract` function of the Holograph Factory
   * reverts with the `HOLOGRAPH: already deployed` error message when the contract is already deployed.
   * Refers to the hardhat test with the description 'should fail contract was already deployed'
   */
  function testDeployRevertContractAlreadyDeployed() public {
    (DeploymentConfig memory deployConfig, bytes32 hashHtokenEth) = getConfigHtokenETH();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKeyDeployer,
      HelperSignEthMessage.toEthSignedMessageHash(hashHtokenEth)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});
    vm.expectRevert(bytes(ErrorConstants.ALREADY_DEPLOYED_ERROR_MSG));
    vm.prank(deployer);
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  /**
   * @notice Test the deployHolographableContract function Revert if the signature R is invalid
   * @dev This test checks that the `deployHolographableContract` function of the Holograph Factory reverts with
   * the `HOLOGRAPH: invalid signature` error message when the provided signature is invalid.
   * Refers to the hardhat test with the description 'should fail with invalid signature if signature.r is incorrect'
   */
  function testDeployRevertSignatureRIncorrect() public {
    (DeploymentConfig memory deployConfig, bytes32 hashHtokenEth) = getConfigHtokenETH();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKeyDeployer,
      HelperSignEthMessage.toEthSignedMessageHash(hashHtokenEth)
    );
    Verification memory signature = Verification({v: v, r: bytes32(invalidSignature), s: s});

    vm.expectRevert(bytes(ErrorConstants.INVALID_SIGNATURE_ERROR_MSG));
    vm.prank(deployer);
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  /**
   * @notice Test the deployHolographableContract function Revert if the signature S is invalid
   * @dev This test checks that the `deployHolographableContract` function of the Holograph Factory reverts with
   * the `HOLOGRAPH: invalid signature` error message when the provided signature is invalid.
   * Refers to the hardhat test with the description 'should fail with invalid signature if signature.s is incorrect'
   */
  function testDeployRevertSignatureSIncorrect() public {
    (DeploymentConfig memory deployConfig, bytes32 hashHtokenEth) = getConfigHtokenETH();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKeyDeployer,
      HelperSignEthMessage.toEthSignedMessageHash(hashHtokenEth)
    );
    Verification memory signature = Verification({v: v, r: r, s: bytes32(invalidSignature)});

    vm.expectRevert(bytes(ErrorConstants.INVALID_SIGNATURE_ERROR_MSG));
    vm.prank(deployer);
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  /**
   * @notice Test the deployHolographableContract function Revert if the signature V is invalid
   * @dev This test checks that the `deployHolographableContract` function of the Holograph Factory reverts with
   * the `HOLOGRAPH: invalid signature` error message when the provided signature is invalid.
   * Refers to the hardhat test with the description 'should fail with invalid signature if signature.s is incorrect'
   */
  function testDeployRevertSignatureVIncorrect() public {
    (DeploymentConfig memory deployConfig, bytes32 hashHtokenEth) = getConfigHtokenETH();
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKeyDeployer,
      HelperSignEthMessage.toEthSignedMessageHash(hashHtokenEth)
    );
    Verification memory signature = Verification({v: uint8(bytes1(invalidSignature)), r: r, s: s});

    vm.expectRevert(bytes(ErrorConstants.INVALID_SIGNATURE_ERROR_MSG));
    vm.prank(deployer);
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  /**
   * @notice Test the deployHolographableContract function Revert if the signer is invalid
   * @dev This test checks that the `deployHolographableContract` function of the Holograph Factory reverts with
   * the`HOLOGRAPH: invalid signature` error message when the provided signature is invalid.
   * Refers to the hardhat test with the description 'should fail with invalid signature if signer is incorrect'
   */
  function testDeployRevertSignatureSignIncorrect() public {
    (DeploymentConfig memory deployConfig, bytes32 hashHtokenEth) = getConfigHtokenETH();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKeyDeployer,
      HelperSignEthMessage.toEthSignedMessageHash(hashHtokenEth)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    vm.expectRevert(bytes(ErrorConstants.INVALID_SIGNATURE_ERROR_MSG));
    vm.prank(deployer);
    holographFactory.deployHolographableContract(deployConfig, signature, alice);
  }

  /* -------------------------------------------------------------------------- */
  /*                              BridgeIn Section                              */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the bridgeIn function return the expected selector
   * @dev This test checks that the `bridgeIn` function of the Holograph Factory returns the expected selector
   * when called with a valid payload.
   * It retrieves the deployment configuration and hash for the sample ERC721 contract, generates a new valid signature,
   * and encodes the deployment configuration, signature, and deployer address into a payload.
   * Then, calls the `bridgeIn` function with the payload and checks that the returned selector matches the expected value.
   * Refers to the hardhat test with the description 'should return the expected selector from the input payload'
   */
  function testExpectedSelectorFromPayload() public {
    (DeploymentConfig memory deployConfig, bytes32 hashSampleERC721) = getConfigERC721();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKeyDeployer,
      HelperSignEthMessage.toEthSignedMessageHash(hashSampleERC721)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    bytes memory payload = abi.encode(deployConfig, signature, address(deployer));

    vm.prank(deployer);
    bytes4 selector = holographFactory.bridgeIn(uint32(block.chainid), payload);
    assertEq(selector, bytes4(0x08a1eb20));
  }

  /**
   * @notice Test the bridgeIn function revert if the payload data is invalid
   * @dev This test checks that the `bridgeIn` function of the Holograph Factory reverts when called with an invalid payload.
   * It creates an invalid format for the expected payload, calls the `bridgeIn` function and and expects the function to revert.
   * Refers to the hardhat test with the description 'should revert if payload data is invalid'
   */
  function testRevertDataPayloadInvalid() public {
    bytes memory payload = Constants.EMPTY_BYTES;

    vm.expectRevert();
    vm.prank(deployer);
    holographFactory.bridgeIn(uint32(block.chainid), payload);
  }

  /* -------------------------------------------------------------------------- */
  /*                              BridgeOut Section                             */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the bridgeOut function
   * @dev This test checks that the `bridgeOut` function of the Holograph Factory returns the expected
   * selector when called with a valid payload.
   * It retrieves the deployment configuration and hash for the sample ERC721 contract, generates a new valid signature,
   * and encodes the deployment configuration, signature, and deployer address into a payload.
   * Calls the `bridgeOut` function with the payload and checks that the returned selector matches the expected value.
   * Refers to the hardhat test with the description 'should return selector and payload'
   */
  function testContemplateSelectorFromPayload() public {
    (DeploymentConfig memory deployConfig, bytes32 hashSampleERC721) = getConfigERC721();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKeyDeployer,
      HelperSignEthMessage.toEthSignedMessageHash(hashSampleERC721)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    bytes memory payload = abi.encode(deployConfig, signature, address(deployer));
    vm.prank(alice);
    (bytes4 selector, bytes memory data) = holographFactory.bridgeOut(1, address(deployer), payload);
    data;
    assertEq(selector, bytes4(0xb7e03661));
  }

  /* -------------------------------------------------------------------------- */
  /*                            setHolograph Section                            */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the setHolograph function when the owner is the one who calls her
   * @dev This test checks that the `setHolograph` function of the Holograph Factory can be called by the admin
   * to update the Holograph contract address stored in the factory.
   * It first pranks as the deployer and calls the `setHolograph` function to update the Holograph address.
   * It then asserts that the updated Holograph address matches the expected value.
   * Refers to the hardhat test with the description ' should allow admin to alter _holographSlot'
   */

  function testAllowAdminAlterHolographSlot() public {
    vm.prank(deployer);
    holographFactory.setHolograph(address(holograph));
    assertEq(holographFactory.getHolograph(), address(holograph));
  }

  /**
   * @notice Test the setHolograph function when the not owner is the one who calls her and revert
   * @dev This test checks that the `setHolograph` function of the Holograph Factory reverts when called by a non-admin.
   * It pranks as a new owner and attempts to call the `setHolograph` function.
   * The test expects the function to revert with the `HOLOGRAPH: admin only function` error message.
   * Refers to the hardhat test with the description 'should fail to allow not owner to alter _holographSlot'
   */

  function testRevertNotAdminAllowAlterHolographSlot() public {
    vm.prank(newOwner);
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holographFactory.setHolograph(address(holograph));
  }

  /* -------------------------------------------------------------------------- */
  /*                             setRegestry Section                            */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the setRegistry function when the owner is the one who calls her
   * @dev This test checks that the `setRegistry` function of the Holograph Factory can be called by the admin
   * to update the registry contract address stored in the factory.
   * It first pranks as the deployer and calls the `setRegistry` function to update the registry address.
   * It then asserts that the updated registry address matches the expected value.
   * Refers to the hardhat test with the description 'should allow admin to alter _registrySlot'
   */

  function testAllowAdminAlterRegistrySlot() public {
    vm.prank(deployer);
    holographFactory.setRegistry(address(holographRegistry));
    assertEq(holographFactory.getRegistry(), address(holographRegistry));
  }

  /**
   * @notice Test the setRegistry function when the not owner is the one who calls her and revert
   * @dev This test checks that the `setRegistry` function of the Holograph Factory reverts when called by a non-admin.
   * It pranks as a new owner and attempts to call the `setRegistry` function.
   * The test expects the function to revert with the `HOLOGRAPH: admin only function` error message.
   * Refers to the hardhat test with the description 'should fail to allow owner to alter _registrySlot'
   */

  function testRevertNotAdminAllowAlterRegistrySlot() public {
    vm.prank(newOwner);
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    holographFactory.setRegistry(address(holographRegistry));
  }

  /* -------------------------------------------------------------------------- */
  /*                          Receive/Fallback Section                          */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Test the receive function in the contract must revert
   * @dev This test checks that the `transfer` function of the Holograph Factory reverts when called by a non-admin.
   * It pranks as the deployer and attempts to call the `transfer` function. The test expects the function to revert.
   * Refers to the hardhat test with the description 'receive()'
   */

  function testRevertRecive() public {
    vm.prank(deployer);
    vm.expectRevert();
    payable(address(Constants.getHolographFactory())).transfer(1 ether);
  }

  /**
   * @notice Test the fallback function in the contract must revert
   * @dev This test checks that the `transfer` function of the Holograph Factory reverts when called by a non-admin.
   * It pranks as the deployer and attempts to call the `transfer` function. The test expects the function to revert.
   * Refers to the hardhat test with the description 'fallback()'
   */
  function testRevertFallback() public {
    vm.prank(deployer);
    vm.expectRevert();
    payable(address(Constants.getHolographFactory())).transfer(0);
  }
}
