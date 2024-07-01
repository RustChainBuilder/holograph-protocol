// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Constants, ErrorConstants} from "../utils/Constants.sol";
import {Holographer} from "../../../src/enforcer/Holographer.sol";
import {Holograph} from "../../../src/Holograph.sol";
import {MockExternalCall} from "../../../src/mock/MockExternalCall.sol";
import {SampleERC721} from "../../../src/token/SampleERC721.sol";
import {HelperDeploymentConfig} from "../utils/HelperDeploymentConfig.sol";
import {DeploymentConfig} from "../../../src/struct/DeploymentConfig.sol";
import {HelperSignEthMessage} from "../utils/HelperSignEthMessage.sol";
import {Verification} from "../../../src/struct/Verification.sol";
import {HolographFactory} from "../../../src/HolographFactory.sol";

/**
 * @title Testing the Holographer
 * @notice Suite of unit tests for the Holographer contract
 * @dev Translation of a suite of Hardhat tests found in test/17_holographer_tests.ts
 */
contract HolographerTests is Test {
  MockExternalCall mockExternalCall;
  HolographFactory factory;
  SampleERC721 sampleERC721;
  Holograph holograph;
  Holographer holographer;
  address zeroAddress = Constants.zeroAddress;
  uint256 privateKeyDeployer = Constants.getPKDeployer();
  address deployer = vm.addr(Constants.getPKDeployer());
  uint256 localHostFork;
  string LOCALHOST_RPC_URL = vm.envString("LOCALHOST_RPC_URL");
  bytes32 holographERC721Hash = Constants.holographERC721Hash;

  /**
   * @notice Deploys the Holographer contract
   * @dev This function deploys the Holographer contract using the provided configuration and signature.
   * It generates the deployment configuration using the HelperDeploymentConfig, signs the configuration
   * with the deployer's private key, and then deploys the Holographer contract using the factory contract.
   * The function also records the logs of the deployment and verifies that the BridgeableContractDeployed
   * event was emitted with the correct address and hash.
   * @return The address of the deployed Holographer contract.
   */
  function deployHolographer() public returns (address) {
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getDeployConfigERC721(
      holographERC721Hash,
      Constants.getHolographIdL1(),
      vm.getCode("SampleERC721.sol:SampleERC721"),
      "Sample ERC721 Contract: unit test",
      "SMPLR",
      Constants.eventConfig,
      1000,
      HelperDeploymentConfig.getInitCodeSampleErc721()
    );

    bytes32 hashERC721 = HelperDeploymentConfig.getDeployConfigHash(deployConfig, deployer);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      privateKeyDeployer,
      HelperSignEthMessage.toEthSignedMessageHash(hashERC721)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    vm.prank(deployer);
    vm.recordLogs();
    factory.deployHolographableContract(deployConfig, signature, deployer);
    Vm.Log[] memory logs = vm.getRecordedLogs();

    address holographerAddress = address(uint160(uint256(logs[1].topics[1])));
    assertEq(logs[1].topics[0], keccak256("BridgeableContractDeployed(address,bytes32)"));
    return holographerAddress;
  }

  /**
   * @notice Sets up the test environment
   * @dev This function sets up the test environment by:
   * 1. Creating a local fork using the `vm.createFork()` function.
   * 2. Initializing the `HolographFactory` and `Holograph` contracts using the `Constants` contract.
   * 3. Deploying a new `MockExternalCall` contract.
   * 4. Calling the `deployHolographer()` function to deploy the Holographer contract.
   */
  function setUp() public {
    localHostFork = vm.createFork(LOCALHOST_RPC_URL);
    vm.selectFork(localHostFork);
    factory = HolographFactory(payable(Constants.getHolographFactoryProxy()));
    holograph = Holograph(payable(Constants.getHolograph()));
    mockExternalCall = new MockExternalCall();
    address holographerAddress = deployHolographer();
    holographer = Holographer(payable(holographerAddress));
  }

  /* -------------------------------------------------------------------------- */
  /*                                 Constructor                                */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the constructor sets the address of the sample ERC721 holographer
   * @dev This test verifies that the constructor sets the address of the sample ERC721 holographer
   * to a non-zero address.
   * Refers to the hardhat test with the description 'should successfully deploy'
   */
  function testConstructor() public {
    assertNotEq(address(holographer), zeroAddress);
  }

  /* -------------------------------------------------------------------------- */
  /*                                    Init                                    */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the init function reverts when called twice
   * @dev This test verifies that the init function of the holographer contract reverts when called twice.
   * Refers to the hardhat test with the description 'should fail if already initialized'
   */
  function testInit() public {
    bytes32[] memory emptyBytes32Array;
    bytes memory initCode = abi.encode(deployer, emptyBytes32Array);
    vm.expectRevert(bytes(ErrorConstants.HOLOGRAPHER_ALREADY_INITIALIZED_ERROR_MSG));
    vm.prank(deployer);
    holographer.init(initCode);
  }

  /* -------------------------------------------------------------------------- */
  /*                             getDeploymentBlock                             */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the getDeploymentBlock function returns a valid block height
   * @dev This test verifies that the getDeploymentBlock function of the holographer contract
   * returns a block height greater than zero.
   * Refers to the hardhat test with the description 'Should return valid _blockHeightSlot'
   */
  function testReturnValidBlockHeightSlot() public {
    uint256 deploymentBlock = holographer.getDeploymentBlock();
    assertNotEq(deploymentBlock, 0);
  }

  /**
   * @notice Tests that an external contract can call the getDeploymentBlock function
   * @dev This test verifies that an external contract (in this case, the mockExternalCall contract)
   * can successfully call the getDeploymentBlock function of the holographer contract.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnGetDeploymentBlock() public {
    bytes memory encodedFunctionData = abi.encodeWithSignature("getDeploymentBlock()");
    vm.prank(deployer);
    mockExternalCall.callExternalFn(address(holographer), encodedFunctionData);
  }

  /* -------------------------------------------------------------------------- */
  /*                                getHolograph                                */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the getHolograph function returns a valid Holograph address
   * @dev This test verifies that the getHolograph function of the holographer contract returns
   * the expected Holograph address.
   * Refers to the hardhat test with the description 'Should return valid _holographSlot'
   */
  function testReturnValidHolographSlot() public {
    assertEq(holographer.getHolograph(), address(holograph));
  }

  /**
   * @notice Tests that an external contract can call the getHolograph function
   * @dev This test verifies that an external contract (in this case, the mockExternalCall contract)
   * can successfully call the getHolograph function of the holographer contract.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnGetHolograph() public {
    bytes memory encodedFunctionData = abi.encodeWithSignature("getHolograph()");
    vm.prank(deployer);
    mockExternalCall.callExternalFn(address(holographer), encodedFunctionData);
  }

  /* -------------------------------------------------------------------------- */
  /*                                getOriginChain                              */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the getOriginChain function returns a valid origin chain
   * @dev This test verifies that the getOriginChain function of the holographer contract
   * returns the expected origin chain.
   * Refers to the hardhat test with the description 'Should return valid _originChainSlot'
   */
  function testReturnValidOriginChainSlot() public {
    assertEq(holographer.getOriginChain(), holograph.getHolographChainId());
  }

  /**
   * @notice Tests that an external contract can call the getOriginChain function
   * @dev This test verifies that an external contract (in this case, the mockExternalCall contract)
   * can successfully call the getOriginChain function of the holographer contract.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnGetOriginChain() public {
    bytes memory encodedFunctionData = abi.encodeWithSignature("getOriginChain()");
    vm.prank(deployer);
    mockExternalCall.callExternalFn(address(holographer), encodedFunctionData);
  }

  /* -------------------------------------------------------------------------- */
  /*                                getSourceContract                           */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the getSourceContract function returns a valid source contract
   * @dev This test verifies that the getSourceContract function of the holographer
   * contract returns a non-zero address.
   * Refers to the hardhat test with the description 'Should return valid _sourceContractSlot'
   */
  function testReturnValidSourceContractSlot() public {
    assertNotEq(holographer.getSourceContract(), zeroAddress);
  }

  /**
   * @notice Tests that an external contract can call the getSourceContract function
   * @dev This test verifies that an external contract (in this case, the mockExternalCall contract)
   * can successfully call the getSourceContract function of the holographer contract.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnGetSourceContract() public {
    bytes memory encodedFunctionData = abi.encodeWithSignature("getSourceContract()");
    vm.prank(deployer);
    mockExternalCall.callExternalFn(address(holographer), encodedFunctionData);
  }

  /* -------------------------------------------------------------------------- */
  /*                                getHolographEnforcer                        */
  /* -------------------------------------------------------------------------- */
  /**
   * @notice Tests that the getHolographEnforcer function returns a valid holograph enforcer
   * @dev This test verifies that the getHolographEnforcer function of the holographer
   * contract returns a non-zero address.
   * Refers to the hardhat test with the description 'Should return Holograph smart contract
   * that controls and enforces the ERC standards'
   */
  function testReturnHolographSmartContract() public {
    assertNotEq(holographer.getHolographEnforcer(), zeroAddress);
  }

  /**
   * @notice Tests that an external contract can call the getHolographEnforcer function
   * @dev This test verifies that an external contract (in this case, the mockExternalCall contract)
   * can successfully call the getHolographEnforcer function of the holographer contract.
   * Refers to the hardhat test with the description 'Should allow external contract to call fn'
   */
  function testAllowExternalContractToCallFnGetHolographEnforcer() public {
    bytes memory encodedFunctionData = abi.encodeWithSignature("getHolographEnforcer()");
    vm.prank(deployer);
    mockExternalCall.callExternalFn(address(holographer), encodedFunctionData);
  }
}
