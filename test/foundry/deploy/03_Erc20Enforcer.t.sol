// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Constants, ErrorConstants} from "../utils/Constants.sol";
import {HolographERC20} from "../../../src/enforcer/HolographERC20.sol";
import {Holographer} from "../../../src/enforcer/Holographer.sol";
import {SampleERC20} from "../../../src/token/SampleERC20.sol";
import {ERC20Mock} from "../../../src/mock/ERC20Mock.sol";
import {Admin} from "../../../src/abstract/Admin.sol";
import {ERC20} from "../../../src/interface/ERC20.sol";
import {PermitSigUtils} from "../utils/PermitSigUtils.sol";

/**
 * @title Testing the Holograph ERC20 Enforcer (CHAIN1)
 * @notice Suite of unit tests for the Holograph ERC20 Enforcer contract deployed on CHAIN1
 * @dev Translation of a suite of Hardhat tests found in test/03_erc20_enforcer_tests_l1.ts
 */

contract Erc20Enforcer is Test {
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  uint256 localHostFork;
  string LOCALHOST_RPC_URL = vm.envString("LOCALHOST_RPC_URL");
  HolographERC20 holographERC20;
  Holographer holographer;
  SampleERC20 sampleERC20;
  ERC20Mock erc20Mock;
  Admin admin;
  PermitSigUtils permitSigUtils;
  uint16 tokenDecimals = 18;
  uint256 privateKeyDeployer = Constants.getPKDeployer();
  address deployer = vm.addr(Constants.getPKDeployer());
  address alice = vm.addr(1);
  address bob = vm.addr(2);
  uint256 initialValue = 1;
  bytes zeroBytes = Constants.EMPTY_BYTES;
  uint256 maxValue = Constants.MAX_UINT256;
  uint256 halfValue = Constants.HALF_VALUE;
  uint256 halfInverseValue = Constants.HALF_INVERSE_VALUE;
  bytes32 zeroSignature = Constants.EMPTY_BYTES32;
  bytes32 signature = bytes32(abi.encode(0x1111111111111111111111111111111111111111111111111111111111111111));
  bytes32 signature2 = bytes32(abi.encode(0x35353535353535353535353535353535353535353535353535353535353535));
  bytes32 signature3 = bytes32(abi.encode(0x68686868686868686868686868686868686868686868686868686868686868));
  uint256 badDeadLine;
  uint256 goodDeadLine;

  /**
   * @notice Initializes the test environment and sets up contract instances
   * @dev This function initializes the test environment by creating a fork of the local blockchain, setting the fork, and
   * instantiating contract instances for ERC20Mock, HolographERC20, SampleERC20, and Admin. It also sets up some initial
   * values for deadlines and creates a new instance of PermitSigUtils.
   */
  function setUp() public {
    localHostFork = vm.createFork(LOCALHOST_RPC_URL);
    vm.selectFork(localHostFork);
    erc20Mock = ERC20Mock(payable(Constants.getERC20Mock()));
    holographERC20 = HolographERC20(payable(Constants.getSampleERC20()));
    holographer = Holographer(payable(Constants.getSampleERC20()));
    sampleERC20 = SampleERC20(payable(Constants.getSampleERC20()));
    admin = Admin(payable(Constants.getHolographFactoryProxy()));
    badDeadLine = uint256(block.timestamp) - 1;
    goodDeadLine = uint256(block.timestamp);
    permitSigUtils = new PermitSigUtils(holographERC20.DOMAIN_SEPARATOR());
  }

  /**
   * @notice Computes the EIP-712 domain separator for the Holograph ERC20 Enforcer contract
   * @dev This function computes the EIP-712 domain separator for the Holograph ERC20 Enforcer contract by hashing the name,
   * version, chain ID, and contract address using the `keccak256` function.
   * @param name The name of the contract
   * @param version The version of the contract
   * @param contractAddress The address of the contract
   * @return The computed EIP-712 domain separator
   */
  function buildDomainSeparator(
    uint256 chainid,
    string memory name,
    string memory version,
    address contractAddress
  ) public view returns (bytes32) {
    bytes32 nameHash = keccak256(bytes(name));
    bytes32 versionHash = keccak256(bytes(version));
    bytes32 typeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 addressBytes = bytes32(uint256(uint160(contractAddress)));
    return keccak256(abi.encodePacked(typeHash, nameHash, versionHash, chainid, addressBytes));
  }

  /* -------------------------------------------------------------------------- */
  /*                              HELPER FUNCTIONS                              */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Mints the specified `initialValue` to the address `alice`
   * @dev This test function mints the specified `initialValue` to the address `alice` using the `mint` function of the `sampleERC20` contract.
   */
  function mintToAlice() public {
    vm.prank(deployer);
    sampleERC20.mint(alice, initialValue);
  }

  /**
   * @notice Mints the specified `initialValue` to the deployer address
   * @dev This test function mints the specified `initialValue` to the deployer address using the `mint` function of the `sampleERC20` contract.
   */
  function mintToDeployer() public {
    vm.prank(deployer);
    sampleERC20.mint(deployer, initialValue);
  }

  /**
   * @notice Approves `amount` tokens for `alice` from the deployer address
   * @dev This test function approves `amount` tokens for `alice` from the deployer address using the `approve` function of the `holographERC20` contract.
   */
  function approvalToAlice(uint256 amount) public {
    vm.prank(deployer);
    holographERC20.approve(alice, amount);
  }

  /**
   * @notice Approves `amount` tokens for `bob` from the deployer address
   * @dev This test function approves `amount` tokens for `bob` from the deployer address using the `approve` function of the `holographERC20` contract.
   */
  function approvalToBob(uint256 amount) public {
    vm.prank(deployer);
    holographERC20.approve(bob, amount);
  }

  /**
   * @notice Increases the allowance of `alice` by `amount` tokens from the deployer address
   * @dev This test function increases the allowance of `alice` by `amount` tokens from the deployer address using the `increaseAllowance` function of the `holographERC20` contract.
   */
  function increaseAllowanceToAlice(uint256 amount) public {
    vm.prank(deployer);
    holographERC20.increaseAllowance(alice, amount);
  }

  /**
   * @notice Decreases the allowance of `alice` by `amount` tokens from the deployer address
   * @dev This test function decreases the allowance of `alice` by `amount` tokens from the deployer address using the `decreaseAllowance` function of the `holographERC20` contract.
   */
  function decreaseAllowanceToAlice(uint256 amount) public {
    vm.prank(deployer);
    holographERC20.decreaseAllowance(alice, amount);
  }

  /* -------------------------------------------------------------------------- */
  /*                               INIT INTERFACES                              */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Verifies that the ERC20 contract supports the ERC165 interface
   * @dev This test checks if the ERC20 contract supports the ERC165 interface by calling the supportsInterface function
   * with the ERC165 interface ID.
   * Refers to the hardhat test with the description 'supportsInterface supported'
   */
  function testSupportinterface() public view {
    bytes4 selector = holographERC20.supportsInterface.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the allowance interface
   * @dev This test checks if the ERC20 contract supports the allowance interface by calling the supportsInterface
   * function with the selector of the allowance function.
   * Refers to the hardhat test with the description 'allowance supported'
   */
  function testAllowanceInterface() public view {
    bytes4 selector = holographERC20.allowance.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the approve interface
   * @dev This test checks if the ERC20 contract supports the approve interface by calling the supportsInterface
   * function with the selector of the approve function.
   * Refers to the hardhat test with the description 'approve supported'
   */
  function testApproveInterface() public view {
    bytes4 selector = holographERC20.approve.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the balanceOf interface
   * @dev This test checks if the ERC20 contract supports the balanceOf interface by calling the supportsInterface
   * function with the selector of the balanceOf function.
   * Refers to the hardhat test with the description 'balanceOf supported'
   */
  function testBalanceOfInterface() public view {
    bytes4 selector = holographERC20.balanceOf.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the totalSupply interface
   * @dev This test checks if the ERC20 contract supports the totalSupply interface by calling the supportsInterface
   * function with the selector of the totalSupply function.
   * Refers to the hardhat test with the description 'totalSupply supported'
   */
  function testTotalSupplyInterface() public view {
    bytes4 selector = holographERC20.totalSupply.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the transfer interface
   * @dev This test checks if the ERC20 contract supports the transfer interface by calling the supportsInterface
   * function with the selector of the transfer function.
   * Refers to the hardhat test with the description 'transfer supported'
   */
  function testTransferInterface() public view {
    bytes4 selector = holographERC20.transfer.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the transferFrom interface
   * @dev This test checks if the ERC20 contract supports the transferFrom interface by calling the supportsInterface
   * function with the selector of the transferFrom function.
   * Refers to the hardhat test with the description 'transferFrom supported'
   */
  function testTransferFromInterface() public view {
    bytes4 selector = holographERC20.transferFrom.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the ERC20 interface
   * @dev This test checks if the ERC20 contract supports the ERC20 interface by computing the interface ID and calling
   * the supportsInterface function with the computed ID.
   * Refers to the hardhat test with the description 'ERC20 interface supported'
   */
  function testERC20Interface() public view {
    bytes4 computedId = bytes4(
      holographERC20.allowance.selector ^
        holographERC20.approve.selector ^
        holographERC20.balanceOf.selector ^
        holographERC20.totalSupply.selector ^
        holographERC20.transfer.selector ^
        holographERC20.transferFrom.selector
    );
    assertTrue(holographERC20.supportsInterface(computedId));
  }

  /**
   * @notice Verifies that the ERC20 contract supports the ERC20 interface
   * @dev This test is identical to testERC20Interface(). It left one for the ERC20 interface and another one for holographERC20.
   * This redundancy ensures that even if the holographERC20 interface undergoes changes in the future, the ERC20 interface
   * remains intact and verifiable.
   */
  function testHolographERC20Interface() public view {
    bytes4 computedId = bytes4(
      holographERC20.allowance.selector ^
        holographERC20.approve.selector ^
        holographERC20.balanceOf.selector ^
        holographERC20.totalSupply.selector ^
        holographERC20.transfer.selector ^
        holographERC20.transferFrom.selector
    );
    assertTrue(holographERC20.supportsInterface(computedId));
  }

  /**
   * @notice Verifies that the ERC20 contract supports the name interface
   * @dev This test checks if the ERC20 contract supports the name interface by calling the supportsInterface function with
   * the selector of the name function.
   * Refers to the hardhat test with the description 'name supported'
   */
  function testNameInterface() public view {
    bytes4 selector = holographERC20.name.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the symbol interface
   * @dev This test checks if the ERC20 contract supports the symbol interface by calling the supportsInterface function with
   * the selector of the symbol function.
   * Refers to the hardhat test with the description 'symbol supported'
   */
  function testSymbolInterface() public view {
    bytes4 selector = holographERC20.symbol.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the decimals interface
   * @dev This test checks if the ERC20 contract supports the decimals interface by calling the supportsInterface
   * function with the selector of the decimals function.
   * Refers to the hardhat test with the description 'decimals supported'
   */
  function testDecimalsInterface() public view {
    bytes4 selector = holographERC20.decimals.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the ERC20 metadata interface
   * @dev This test computes the interface ID for ERC20 metadata (name, symbol, decimals) and checks if the ERC20
   * contract supports it.
   * Refers to the hardhat test with the description 'ERC20Metadata interface supported'
   */
  function testERC20MetadataInterface() public view {
    bytes4 computedId = bytes4(
      holographERC20.name.selector ^ holographERC20.symbol.selector ^ holographERC20.decimals.selector
    );
    assertTrue(holographERC20.supportsInterface(computedId));
  }

  /**
   * @notice Verifies that the ERC20 contract supports the burn interface
   * @dev This test checks if the ERC20 contract supports the burn interface by calling the supportsInterface
   * function with the selector of the burn function.
   * Refers to the hardhat test with the description 'burn supported'
   */
  function testBurnInterface() public view {
    bytes4 selector = holographERC20.burn.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the burnFrom interface
   * @dev This test checks if the ERC20 contract supports the burnFrom interface by calling the supportsInterface
   * function with the selector of the burnFrom function.
   * Refers to the hardhat test with the description 'burnFrom supported'
   */
  function testBurnFromInterface() public view {
    bytes4 selector = holographERC20.burnFrom.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the ERC20 burn interface
   * @dev This test computes the interface ID for ERC20 burn (burn, burnFrom) and checks if the ERC20 contract supports it.
   * Refers to the hardhat test with the description 'ERC20Burnable interface supported'
   */
  function testERC20BurnInterface() public view {
    bytes4 computedId = bytes4(holographERC20.burn.selector ^ holographERC20.burnFrom.selector);
    assertTrue(holographERC20.supportsInterface(computedId));
  }

  /**
   * @notice Verifies that the ERC20 contract supports the safeTransfer interface with two arguments
   * @dev This test checks if the ERC20 contract supports the safeTransfer interface with two arguments
   * (address, uint256) by calling the supportsInterface function with the corresponding selector.
   * Refers to the hardhat test with the description 'safeTransfer supported'
   */
  function testSafeTransferInterface() public view {
    holographERC20.supportsInterface(bytes4(keccak256("safeTransfer(address,uint256)")));
  }

  /**
   * @notice Verifies that the ERC20 contract supports the safeTransfer interface with three arguments
   * @dev This test checks if the ERC20 contract supports the safeTransfer interface with three arguments
   * (address, uint256, bytes) by calling the supportsInterface function with the corresponding selector.
   * Refers to the hardhat test with the description 'safeTransfer (with bytes) supported'
   */
  function testSafeTransferInterfaceDiferentCallTwo() public view {
    holographERC20.supportsInterface(bytes4(keccak256("safeTransfer(address,uint256,bytes)")));
  }

  /**
   * @notice Verifies that the ERC20 contract supports the safeTransfer interface with four arguments
   * @dev This test checks if the ERC20 contract supports the safeTransfer interface with four arguments
   * (address, uint256, uint256) by calling the supportsInterface function with the corresponding selector.
   * Refers to the hardhat test with the description 'safeTransferFrom supported'
   */
  function testSafeTransferInterfaceDiferentCallThree() public view {
    holographERC20.supportsInterface(bytes4(keccak256("safeTransfer(address,uint256,uint256)")));
  }

  /**
   * @notice Verifies that the ERC20 contract supports the safeTransfer interface with four arguments
   * @dev This test checks if the ERC20 contract supports the safeTransfer interface with four arguments (address to,
   *  address data, uint256 value, bytes data) by calling the supportsInterface function with the corresponding selector.
   * Refers to the hardhat test with the description 'safeTransferFrom (with bytes) supported'
   */
  function testSafeTransferInterfaceDiferentCallFour() public view {
    holographERC20.supportsInterface(bytes4(keccak256("safeTransfer(address,address,uint256,bytes)")));
  }

  /**
   * @notice Verifies that the contract supports the ERC20 safer interface
   * @dev This test checks if the contract supports the ERC20 safer interface by computing the interface ID for
   * safeTransfer functions and checking if the contract supports it.
   * Refers to the hardhat test with the description 'ERC20Safer interface supported'
   */
  function testERC20SaferInterface() public {
    bytes memory safeTransfer = abi.encodeWithSelector(bytes4(keccak256("safeTransfer(address,uint256)")));
    bytes memory safeTransferBytes = abi.encodeWithSelector(bytes4(keccak256("safeTransfer(address,uint256,bytes)")));
    bytes memory safeTransferFrom = abi.encodeWithSelector(
      bytes4(keccak256("safeTransferFrom(address,address,uint256)"))
    );
    bytes memory safeTransferFromBytes = abi.encodeWithSelector(
      bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"))
    );

    bytes4 computedId = bytes4(
      bytes4(safeTransfer) ^ bytes4(safeTransferBytes) ^ bytes4(safeTransferFrom) ^ bytes4(safeTransferFromBytes)
    );
    assertTrue(holographERC20.supportsInterface(computedId));
  }

  /**
   * @notice Verifies that the ERC20 contract supports the safePermit interface
   * @dev This test checks if the ERC20 contract supports the safePermit interface by calling the supportsInterface
   * function with the selector of the permit function.
   * Refers to the hardhat test with the description 'permit supported'
   */
  function testSafePermitInterface() public view {
    bytes4 selector = holographERC20.permit.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the nonces interface
   * @dev This test checks if the ERC20 contract supports the nonces interface by calling the supportsInterface
   * function with the selector of the nonces function.
   * Refers to the hardhat test with the description 'nonces supported'
   */
  function testNoncesInterface() public view {
    bytes4 selector = holographERC20.nonces.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the domainSeparator interface
   * @dev This test checks if the ERC20 contract supports the domainSeparator interface by calling the supportsInterface
   * function with the selector of the DOMAIN_SEPARATOR function.
   * Refers to the hardhat test with the description 'DOMAIN_SEPARATOR supported'
   */
  function testDomainSeparatorInterface() public view {
    bytes4 selector = holographERC20.DOMAIN_SEPARATOR.selector;
    holographERC20.supportsInterface(selector);
  }

  /**
   * @notice Verifies that the ERC20 contract supports the ERC20 permit interface
   * @dev This test computes the interface ID for ERC20 permit (permit, nonces, DOMAIN_SEPARATOR) and checks if the
   * ERC20 contract supports it.
   * Refers to the hardhat test with the description 'ERC20Permit interface supported'
   */
  function testERC20Permit() public view {
    bytes4 computedId = bytes4(
      holographERC20.permit.selector ^ holographERC20.nonces.selector ^ holographERC20.DOMAIN_SEPARATOR.selector
    );
    assertTrue(holographERC20.supportsInterface(computedId));
  }

  /* -------------------------------------------------------------------------- */
  /*                                  INIT TEST                                 */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Verifies that the initialization of theHolopgraphERC20 reverts if already initialized
   * @dev This test attempts to initialize the contract with a parameter and expects it to revert with the message
   * "HOLOGRAPHER: already initialized".
   * Refers to the hardhat test with the description 'should fail initializing already initialized Holographer'
   */
  function testInitHolographERC20Revert() public {
    bytes memory paramInit = Constants.EMPTY_BYTES;
    vm.expectRevert(bytes(ErrorConstants.HOLOGRAPHER_ALREADY_INITIALIZED_ERROR_MSG));
    holographERC20.init(paramInit);
  }

  /**
   * @notice Verifies that the initialization of the Sample ERC20 Enforcer reverts if already initialized
   * @dev This test attempts to initialize the Sample ERC20 Enforcer contract with some parameters and e
   * xpects it to revert with the message "ERC20: already initialized".
   * Refers to the hardhat test with the description 'should fail initializing already initialized ERC721 Enforcer'
   */
  function testInitSampleERC20EnforcerRevert() public {
    holographer.getHolographEnforcer();
    Holographer sampleERC20Enforcer = Holographer(payable(holographer.getHolographEnforcer()));
    bytes memory initCode = abi.encode(
      "",
      "",
      "0x00",
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      false,
      "0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    vm.expectRevert(bytes(ErrorConstants.ERC20_ALREADY_INITIALIZED_ERROR_MSG));
    sampleERC20Enforcer.init(initCode);
  }

  /* -------------------------------------------------------------------------- */
  /*                                METADATA TEST                               */
  /* -------------------------------------------------------------------------- */

  //TODO change name by network
  /**
   * @notice Verifies that the name of the ERC20 token is "Sample ERC20 Token (localhost)"
   * @dev This test checks the name of the ERC20 token by calling the `name` function and comparing the result to the
   * expected value.
   * Refers to the hardhat test with the description 'token name:'
   */
  function testName() public view {
    assertEq(holographERC20.name(), "Sample ERC20 Token (localhost)");
  }

  /**
   * @notice Verifies that the symbol of the ERC20 token is "SMPL"
   * @dev This test checks the symbol of the ERC20 token by calling the `symbol` function and comparing the result to
   * the expected value.
   * Refers to the hardhat test with the description 'token symbol:'
   */
  function testSymbol() public view {
    assertEq(holographERC20.symbol(), "SMPL");
  }

  /**
   * @notice Verifies that the decimals of the ERC20 token is equal to the `tokenDecimals` variable
   * @dev This test checks the decimals of the ERC20 token by calling the `decimals` function and comparing the result
   * to the `tokenDecimals` variable.
   * Refers to the hardhat test with the description 'token decimals:'
   */
  function testDecimals() public view {
    assertEq(holographERC20.decimals(), tokenDecimals);
  }

  /* -------------------------------------------------------------------------- */
  /*                               MINT TOKEN TEST                              */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Verifies that the total supply of the ERC20 token is 0
   * @dev This test checks the total supply of the ERC20 token by calling the `totalSupply` function and comparing the result to 0.
   * Refers to the hardhat test with the description 'should have a total supply of 0 ' + tokenSymbol + ' tokens'
   */
  function testTotalSupply() public view {
    assertEq(holographERC20.totalSupply(), 0);
  }

  /**
   * @notice Verifies that minting tokens emits the Transfer event
   * @dev This test expects the Transfer event to be emitted when minting tokens to an address.
   * Refers to the hardhat test with the description 'should emit Transfer event for ' + totalTokens + ' ' + tokenSymbol + ' tokens'
   */
  function testMintEmitEvent() public {
    vm.expectEmit(true, true, false, true);
    emit Transfer(Constants.zeroAddress, alice, initialValue);
    mintToAlice();
  }

  /**
   * @notice Verifies that the total supply of the ERC20 token matches the initial value after minting
   * @dev This test mints tokens to an address and then checks if the total supply matches the initial value.
   * Refers to the hardhat test with the description 'should have a total supply of ' + totalTokens + ' ' + tokenSymbol + ' tokens'
   */
  function testTotalSupplyInitialValue() public {
    mintToAlice();
    assertEq(holographERC20.totalSupply(), initialValue);
  }

  /**
   * @notice Verifies that Alice's balance matches the initial value after minting
   * @dev This test mints tokens to Alice and then checks if her balance matches the initial value.
   * Refers to the hardhat test with the description 'deployer wallet should show a balance of ' + totalTokens + ' ' + tokenSymbol + ' tokens'
   */
  function testBalanceAliceInitialValue() public {
    mintToAlice();
    assertEq(holographERC20.balanceOf(alice), initialValue);
  }

  /* -------------------------------------------------------------------------- */
  /*                         ERC20 TEST Tokens Approvals                        */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Verifies that attempting to approve tokens for the zero address reverts with the message "ERC20: spender
   * is zero address"
   * @dev This test expects a revert with the specified message when attempting to approve tokens for the zero address.
   * Refers to the hardhat test with the description 'should fail when approving a zero address'
   */
  function testApprovalRevertZeroAddress() public {
    vm.expectRevert(bytes(ErrorConstants.ERC20_SPENDER_SERO_ADDRESS_ERROR_MSG));
    holographERC20.approve(Constants.zeroAddress, maxValue);
  }

  /**
   * @notice Verifies that approving tokens emits the Approval event
   * @dev This test expects the Approval event to be emitted when approving tokens for an address.
   * Refers to the hardhat test with the description 'should succeed when approving valid address'
   */
  function testApporvalEmitEvent() public {
    vm.expectEmit(true, true, false, true);
    emit Approval(deployer, alice, maxValue);
    approvalToAlice(maxValue);
  }

  /**
   * @notice Verifies that decreasing allowance emits the Approval event
   * @dev This test first increases the allowance to Alice, then expects the Approval event to be emitted when decreasing
   * the allowance above zero.
   * Refers to the hardhat test with the description 'should succeed decreasing allowance above zero'
   */
  function testDecreaseAllowanceEmitEvent() public {
    increaseAllowanceToAlice(maxValue);
    vm.expectEmit(true, true, false, true);
    emit Approval(deployer, alice, halfInverseValue);
    decreaseAllowanceToAlice(halfValue);
  }

  /**
   * @notice Verifies that decreasing the allowance below zero reverts
   * @dev This test first increases the allowance to Alice, then decreases it twice, expecting a revert when trying to
   * decrease it below zero.
   * Refers to the hardhat test with the description 'should fail decreasing allowance below zero'
   */
  function testDecreaseAllowanceBelongToZeroRevert() public {
    increaseAllowanceToAlice(maxValue);
    decreaseAllowanceToAlice(halfValue);
    vm.expectRevert(bytes(ErrorConstants.ERC20_DECREASED_BELOW_ZERO_ERROR_MSG));
    decreaseAllowanceToAlice(maxValue);
  }

  /**
   * @notice Verifies that increasing the allowance above the max value reverts
   * @dev This test first increases the allowance to Alice, then attempts to increase it again, expecting a revert when
   * trying to increase it above the max value.
   * Refers to the hardhat test with the description 'should fail increasing allowance above max value'
   */
  function testIncreaseAllowanceAboveToMaxValueRevert() public {
    increaseAllowanceToAlice(maxValue);
    vm.expectRevert(bytes(ErrorConstants.ERC20_INCREASED_ABOVE_MAX_ERROR_MSG));
    increaseAllowanceToAlice(maxValue);
  }

  /**
   * @notice Verifies that decreasing the allowance to zero succeeds
   * @dev This test first increases the allowance to Alice, then decreases it to zero, expecting the Approval event to be emitted.
   * Refers to the hardhat test with the description 'should succeed decreasing allowance to zero'
   */
  function testDecreaseAllowanceToZero() public {
    increaseAllowanceToAlice(maxValue);
    vm.expectEmit(true, true, false, true);
    emit Approval(deployer, alice, 0);
    decreaseAllowanceToAlice(maxValue);
  }

  /**
   * @notice Verifies that increasing the allowance to the max value succeeds
   * @dev This test increases the allowance to Alice to the max value, expecting the Approval event to be emitted.
   * Refers to the hardhat test with the description 'should succeed increasing allowance to max value'
   */
  function testIncreaseAllowanceToMaxValue() public {
    vm.expectEmit(true, true, false, true);
    emit Approval(deployer, alice, maxValue);
    increaseAllowanceToAlice(maxValue);
  }

  /* -------------------------------------------------------------------------- */
  /*                        ERC20 TEST  Failed Transfers                        */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Verifies that attempting to transfer more tokens than the sender has reverts
   * @dev This test expects a revert with the message "ERC20: amount exceeds balance" when the sender tries to transfer
   * more tokens than they have.
   * Refers to the hardhat test with the description 'should fail if sender doesn't have enough tokens'
   */
  function testTransferNotEnoughTokensRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ERC20_AMOUNT_EXCEEDS_BALANCE_ERROR_MSG));
    holographERC20.transfer(alice, maxValue);
  }

  /**
   * @notice Verifies that attempting to transfer tokens to the zero address reverts
   * @dev This test expects a revert with the message "ERC20: recipient is zero address" when trying to transfer tokens
   * to the zero address.
   * Refers to the hardhat test with the description 'should fail if sending to zero address'
   */
  function testTransferToZeroAddressRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ERC20_RECIPIENT_SERO_ADDRESS__ERROR_MSG));
    holographERC20.transfer(Constants.zeroAddress, maxValue);
  }

  /**
   * @notice Verifies that attempting to transfer tokens from the zero address reverts
   * @dev This test expects a revert with the message "ERC20: amount exceeds allowance" when trying to transfer tokens
   * from the zero address.
   * Refers to the hardhat test with the description 'should fail if sending from zero address'
   */
  function testTransferFromZeroAddressRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ERC20_AMOUNT_EXCEEDS_ALLOWANCE_ERROR_MSG));
    vm.prank(deployer);
    holographERC20.transferFrom(Constants.zeroAddress, alice, maxValue);
  }

  /**
   * @notice Verifies that attempting to transfer tokens from an address not approved to transfer reverts
   * @dev This test expects a revert with the message "ERC20: amount exceeds allowance" when trying to transfer tokens
   * from an address not approved to transfer.
   * Refers to the hardhat test with the description 'should fail if sending from not approved address'
   */
  function testTransferFromNotAprrovalAddressRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ERC20_AMOUNT_EXCEEDS_ALLOWANCE_ERROR_MSG));
    vm.prank(alice);
    holographERC20.transferFrom(deployer, alice, maxValue);
  }

  /**
   * @notice Verifies that attempting to transfer tokens when the allowance is smaller than the transfer amount reverts
   * @dev This test first approves a smaller amount to Bob, then expects a revert with the message "ERC20: amount exceeds
   * allowance" when trying to transfer tokens exceeding the approved amount.
   * Refers to the hardhat test with the description 'should fail if allowance is smaller than transfer amount'
   */
  function testTransferFromSmallerAprrovalAmountRevert() public {
    approvalToBob(halfValue);
    vm.expectRevert(bytes(ErrorConstants.ERC20_AMOUNT_EXCEEDS_ALLOWANCE_ERROR_MSG));
    vm.prank(bob);
    holographERC20.transferFrom(deployer, alice, maxValue);
  }

  /**
   * @notice Verifies that attempting to call onERC20Received from a non-contract address reverts
   * @dev This test expects a revert with the message "ERC20: operator not contract" when trying to call onERC20Received
   * from a non-contract address.
   * Refers to the hardhat test with the description 'should fail for non-contract onERC20Received call',
   * This test is skipped in hardhat
   */
  function testErc20ReceivedNonContractRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ERC20_OPERATOR_NOT_CONTRACT_ERROR_MSG));
    holographERC20.onERC20Received(deployer, deployer, initialValue, Constants.EMPTY_BYTES);
  }

  //TODO see why mock token have balance?
  /**
   * @dev Refers to the test with description 'should fail for fake onERC20Received', which is skipped in hardhat.
   */
  function testErc20ReceivedFakeContractRevert() public {
    vm.skip(true);
    vm.expectRevert(bytes(ErrorConstants.ERC20_BALANCE_CHECK_FAILED_ERROR_MSG));
    holographERC20.onERC20Received(address(erc20Mock), deployer, initialValue, Constants.EMPTY_BYTES);
  }

  //TODO see why revert ( amount exceeds balance, need mint and then not fail... ) and not non ERC20Received,
  /**
   * @dev Refers to the test with description 'should fail safe transfer for broken "ERC20Receiver', which is skipped in hardhat.
   */
  function testSafeTransferBrokenErc20ReceivedRevert() public {
    vm.skip(true);
    erc20Mock.toggleWorks(false);
    vm.expectRevert(bytes(ErrorConstants.ERC20_NON_ERC20RECEIVER_ERROR_MSG));
    vm.prank(deployer);
    holographERC20.safeTransfer(address(erc20Mock), initialValue);
  }

  //TODO see why revert ( amount exceeds balance,need mint and then not fail... ) and not non ERC20Receiver,
  /**
   * @dev Refers to the test with description 'should fail safe transfer (with bytes) for broken "ERC20Receiver',
   * which is skipped in hardhat.
   */
  function testSafeTransferBytesBrokenErc20ReceivedRevert() public {
    vm.skip(true);
    erc20Mock.toggleWorks(false);
    vm.expectRevert(bytes(ErrorConstants.ERC20_NON_ERC20RECEIVER_ERROR_MSG));
    vm.prank(deployer);
    holographERC20.safeTransfer(address(erc20Mock), initialValue, Constants.EMPTY_BYTES);
  }

  //TODO see why not revert
  /**
   * @dev Refers to the test with description 'should fail safe transfer from for broken "ERC20Receiver',
   * which is skipped in hardhat.
   */
  function testSafeTransferFromBrokenErc20ReceivedRevert() public {
    vm.skip(true);
    vm.prank(deployer);
    sampleERC20.mint(deployer, halfValue);
    erc20Mock.toggleWorks(false);

    approvalToAlice(maxValue);
    vm.expectRevert(bytes(ErrorConstants.ERC20_NON_ERC20RECEIVER_ERROR_MSG));
    vm.prank(alice);

    holographERC20.safeTransferFrom(address(deployer), address(erc20Mock), initialValue);
  }

  //TODO see why not revert
  /**
   * @dev Refers to the test with description 'should fail safe transfer from (with bytes) for broken "ERC20Receiver',
   * which is skipped in hardhat.
   */
  function testSafeTransferFromBytesBrokenErc20RecivedRevert() public {
    vm.skip(true);
    vm.prank(deployer);
    sampleERC20.mint(deployer, halfValue);
    erc20Mock.toggleWorks(false);
    approvalToAlice(maxValue);
    vm.expectRevert(bytes(ErrorConstants.ERC20_NON_ERC20RECEIVER_ERROR_MSG));
    vm.prank(alice);
    holographERC20.safeTransferFrom(address(deployer), address(erc20Mock), initialValue, zeroBytes);
  }

  /* -------------------------------------------------------------------------- */
  /*                      ERC20 TEST   Successful Transfers                     */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Verifies that transferring available tokens succeeds
   * @dev This test first mints tokens to the deployer, then checks that a Transfer event is emitted with the correct
   * parameters, and finally transfers the tokens from the deployer to another address.
   * Refers to the hardhat test with the description 'should succeed when transferring available tokens'.
   */
  function testTransfer() public {
    mintToDeployer();
    vm.expectEmit(true, true, false, true);
    emit Transfer(address(deployer), address(alice), initialValue);
    vm.prank(deployer);
    holographERC20.transfer(address(alice), initialValue);
  }

  /**
   * @notice Verifies that the deployer's token balance is 0 after transferring all tokens
   * @dev This test first mints tokens to the deployer, then transfers all tokens to another address, and finally checks
   * that the deployer's token balance is 0.
   * Refers to the hardhat test with the description 'deployer should have a balance of 0 ' + tokenSymbol + ' tokens'
   */
  function testBalanceOfDeployer() public {
    mintToDeployer();
    vm.prank(deployer);
    holographERC20.transfer(address(alice), initialValue);
    assertEq(holographERC20.balanceOf(deployer), 0);
  }

  /**
   * @notice Verifies that Alice's token balance is correct after transferring tokens
   * @dev This test first mints tokens to the deployer, then transfers all tokens to Alice, and finally checks that
   * Alice's token balance is correct.
   * Refers to the hardhat test with the description 'wallet1 should have a balance of ' + totalTokens + ' ' + tokenSymbol + ' tokens'
   */
  function testBalanceOfAlice() public {
    mintToDeployer();
    vm.prank(deployer);
    holographERC20.transfer(address(alice), initialValue);
    assertEq(holographERC20.balanceOf(alice), initialValue);
  }

  /**
   * @notice Verifies that safely transferring available tokens succeeds
   * @dev This test first mints tokens to Alice, then emits a Transfer event with the expected parameters,
   * and finally safely transfers the tokens to the deployer.
   * Refers to the hardhat test with the description 'should succeed when safely transferring available tokens'
   */
  function testSafeTransfer() public {
    mintToAlice();
    vm.expectEmit(true, true, false, true);
    emit Transfer(address(alice), address(deployer), initialValue);
    vm.prank(alice);
    holographERC20.safeTransfer(address(deployer), initialValue);
  }

  /**
   * @notice Verifies that safely transferring tokens from the available balance succeeds
   * @dev This test first mints tokens to the deployer, then approves Alice to transfer tokens, emits a Transfer
   *  event with the expected parameters, and finally safely transfers the tokens from the deployer to Alice.
   * Refers to the hardhat test with the description 'should succeed when safely transferring from available tokens'
   */
  function testSafeTransferFrom() public {
    mintToDeployer();
    approvalToAlice(initialValue);
    vm.expectEmit(true, true, false, true);
    emit Transfer(address(deployer), address(alice), initialValue);
    vm.prank(alice);
    holographERC20.safeTransferFrom(address(deployer), address(alice), initialValue);
  }

  /**
   * @notice Verifies that the deployer's token balance is 0 after safely transferring tokens from the deployer to another address
   * @dev This test first mints tokens to the deployer, then approves another address to transfer tokens, safely transfers
   * the tokens from the deployer to that address, and finally checks that the deployer's token balance is 0.
   * Refers to the hardhat test with the description 'wallet1 should have a balance of 0 ' + tokenSymbol + ' tokens'
   */
  function testBalanceOfDeployerAfterSafeTransferFrom() public {
    testSafeTransferFrom();
    assertEq(holographERC20.balanceOf(deployer), 0);
  }

  /**
   * @notice Verifies that the balance of Alice is updated correctly after a safe transfer from
   * @dev This test first executes a safe transfer from the deployer to Alice and then checks if the balance of Alice is
   * updated correctly.
   * Refers to the hardhat test with the description 'deployer should have a balance of ' + totalTokens + ' ' + tokenSymbol + ' tokens'
   */
  function testBalanceOfAliceAfterSafeTransferFrom() public {
    testSafeTransferFrom();
    assertEq(holographERC20.balanceOf(alice), initialValue);
  }

  /**
   * @notice Verifies that transferring tokens from the available balance succeeds and updates the allowance accordingly
   * @dev This test first mints tokens to the deployer, approves Alice to transfer tokens, checks the allowance, safely
   * transfers the tokens from the deployer to Alice, and finally checks that the allowance has been updated to 0.
   * Refers to the hardhat test with the description 'should succeed when transferring using an approved spender'
   */
  function testTransferFrom() public {
    mintToDeployer();
    vm.expectEmit(true, true, false, true);
    emit Approval(deployer, alice, initialValue);
    approvalToAlice(initialValue);
    //check allowance alice = 1
    assertEq(holographERC20.allowance(deployer, alice), initialValue);
    vm.expectEmit(true, true, false, true);
    emit Transfer(address(deployer), address(alice), initialValue);
    vm.prank(alice);
    holographERC20.transferFrom(address(deployer), address(alice), initialValue);
    //check allowance alice = 0. A separate test should be done to verify the decrease in alowance.
    assertEq(holographERC20.allowance(deployer, alice), 0);
  }

  /**
   * @notice Verifies that safely transferring tokens to an ERC20Receiver contract succeeds
   * @dev This test first enables the ERC20Receiver mock contract, mints tokens to the deployer, safely transfers the tokens
   * to the ERC20Receiver contract, checks that the ERC20Receiver contract has received the tokens, and finally checks that
   * the deployer's token balance is updated accordingly.
   * Refers to the hardhat test with the description 'should succeed safe transfer to "ERC20Receiver"'
   */
  function testSafeTransferToErc20Reciver() public {
    erc20Mock.toggleWorks(true);
    mintToDeployer();
    vm.expectEmit(true, true, false, true);
    emit Transfer(address(deployer), address(erc20Mock), initialValue);
    vm.prank(deployer);
    holographERC20.safeTransfer(address(erc20Mock), initialValue);
    vm.expectEmit(true, true, false, true);
    emit Transfer(address(erc20Mock), address(deployer), initialValue);
    erc20Mock.transferTokens(payable(holographERC20), deployer, initialValue);
  }

  /**
   * @notice Verifies that safely transferring tokens with data to an ERC20Receiver contract succeeds
   * @dev This test first enables the ERC20Receiver mock contract, mints tokens to the deployer, safely transfers the tokens
   * with data to the ERC20Receiver contract, and checks that the transfer was successful.
   * Refers to the hardhat test with the description 'should succeed safe transfer (with bytes) to "ERC20Receiver"'
   */
  function testSafeTransferWithBytesToErc20Reciver() public {
    erc20Mock.toggleWorks(true);
    mintToDeployer();
    vm.expectEmit(true, true, false, true);
    emit Transfer(address(deployer), address(erc20Mock), initialValue);
    vm.prank(deployer);
    holographERC20.safeTransfer(address(erc20Mock), initialValue, zeroBytes);
  }

  /**
   * @notice Verifies that safely transferring tokens from one address to an ERC20Receiver contract succeeds
   * @dev This test first mints tokens to the deployer, enables the ERC20Receiver mock contract, approves Alice to transfer
   * tokens, checks the allowance, safely transfers the tokens from the deployer to the ERC20Receiver contract, and
   * finally checks that the allowance has been updated to 0.
   * Refers to the hardhat test with the description 'should succeed safe transfer from to "ERC20Receiver"'
   */
  function testSafeTransferFromToErc20() public {
    mintToDeployer();
    erc20Mock.toggleWorks(true);
    vm.expectEmit(true, true, false, true);
    emit Approval(deployer, alice, initialValue);
    approvalToAlice(initialValue);
    //check allowance alice = 1
    assertEq(holographERC20.allowance(deployer, alice), initialValue);
    vm.expectEmit(true, true, false, true);
    emit Transfer(address(deployer), address(erc20Mock), initialValue);
    vm.prank(alice);
    holographERC20.safeTransferFrom(address(deployer), address(erc20Mock), initialValue);
    //check allowance alice = 0
    assertEq(holographERC20.allowance(deployer, alice), 0);
  }

  /**
   * @notice Verifies that safely transferring tokens with data from one address to an ERC20Receiver contract succeeds
   * @dev This test first mints tokens to the deployer, enables the ERC20Receiver mock contract, approves Alice
   * to transfer tokens, checks the allowance, safely transfers the tokens with data from the deployer to the
   *  ERC20Receiver contract, and finally checks that the allowance has been updated to 0.
   * Refers to the hardhat test with the description 'should succeed safe transfer (with bytes) to "ERC20Receiver"'
   */
  function testSafeTransferFromBytesToErc20() public {
    mintToDeployer();
    erc20Mock.toggleWorks(true);
    approvalToAlice(initialValue);
    //check allowance alice = 1
    assertEq(holographERC20.allowance(deployer, alice), initialValue);
    vm.expectEmit(true, true, false, true);
    emit Transfer(address(deployer), address(erc20Mock), initialValue);
    vm.prank(alice);
    holographERC20.safeTransferFrom(address(deployer), address(erc20Mock), initialValue, zeroBytes);
    //check allowance alice = 0
    assertEq(holographERC20.allowance(deployer, alice), 0);
  }

  /* -------------------------------------------------------------------------- */
  /*                           ERC20 TEST   Burneable                           */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Verifies that attempting to burn more tokens than the current balance fails
   * @dev This test attempts to burn more tokens than the current balance and checks that it reverts with the expected
   * error message.
   * Refers to the hardhat test with the description 'should fail burning more tokens than current balance'
   */
  function testBurneableExceedsBalanceRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ERC20_AMOUNT_EXCEEDS_BALANCE_ERROR_MSG));
    holographERC20.burn(initialValue);
  }

  /**
   * @notice Verifies that burning the current balance succeeds
   * @dev This test mints tokens to the deployer, transfers them to the zero address (burning them), and checks that the
   * transfer was successful.
   * Refers to the hardhat test with the description 'should succeed burning current balance'
   */
  function testBurn() public {
    mintToDeployer();
    vm.expectEmit(true, true, false, true);
    emit Transfer(address(deployer), Constants.zeroAddress, initialValue);
    vm.prank(deployer);
    holographERC20.burn(initialValue);
  }

  /**
   * @notice Verifies that attempting to burn tokens via a spender who is not approved fails
   * @dev This test expects a revert with the message "ERC20: amount exceeds allowance" when trying to burn tokens via
   * a spender who is not approved.
   * Refers to the hardhat test with the description 'should fail burning via not approved spender'
   */
  function testBurnFromNotApproveRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ERC20_AMOUNT_EXCEEDS_ALLOWANCE_ERROR_MSG));
    vm.prank(alice);
    holographERC20.burnFrom(deployer, initialValue);
  }

  /**
   * @notice Verifies that burning tokens via an approved spender succeeds
   * @dev This test mints tokens to the deployer, approves Alice to spend tokens, burns tokens via Alice (an approved spender),
   * and checks that the burn operation was successful.
   * Refers to the hardhat test with the description 'should succeed burning via approved spender'
   */
  function testBurnFrom() public {
    mintToDeployer();
    approvalToAlice(initialValue);
    vm.expectEmit(true, true, false, true);
    emit Transfer(address(deployer), Constants.zeroAddress, initialValue);
    vm.prank(alice);
    holographERC20.burnFrom(deployer, initialValue);
  }

  /* -------------------------------------------------------------------------- */
  /*                             ERC20 TEST   Permit                            */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Verifies that the function returns the correct domain separator
   * @dev This test checks if the DOMAIN_SEPARATOR function returns the expected domain separator value for the ERC20
   * token contract.
   * Refers to the hardhat test with the description 'should return correct domain seperator'
   */
  function testCheckDomainSeparator() public {
    assertEq(
      holographERC20.DOMAIN_SEPARATOR(),
      buildDomainSeparator(uint256(block.chainid), "Sample ERC20 Token", "1", address(holographERC20))
    );
  }

  /**
   * @notice Verifies that the nonce for an address is initially 0
   * @dev This test checks if the nonce for the Alice address is initially 0.
   * Refers to the hardhat test with the description 'should return 0 nonce'
   */
  function testPermitZeroNonce() public view {
    assertEq(holographERC20.nonces(alice), 0);
  }

  /**
   * @notice Verifies that attempting a permit with an expired deadline fails
   * @dev This test expects a revert with the message "ERC20: expired deadline" when trying to execute a permit with
   * a bad deadline.
   * Refers to the hardhat test with the description 'should fail for expired deadline'
   */
  function testPermitBadDeadLineRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ERC20_EXPIRED_DEADLINE_ERROR_MSG));
    holographERC20.permit(deployer, alice, initialValue, badDeadLine, uint8(0x00), zeroSignature, zeroSignature);
  }

  /**
   * @notice Verifies that attempting a permit with an empty signature fails
   * @dev This test expects a revert with the message "ERC20: zero address signer" when trying to execute a permit
   * with an empty signature.
   * Refers to the hardhat test with the description 'should fail for empty signature'
   */
  function testPermitEmptySignatureRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ERC20_ZERO_ADDRESS_SIGNER_ERROR_MSG));
    holographERC20.permit(deployer, alice, initialValue, goodDeadLine, uint8(0x1b), zeroSignature, zeroSignature);
  }

  /**
   * @notice Verifies that attempting a permit with a zero address signature fails
   * @dev This test expects a revert with the message "ERC20: zero address signer" when trying to execute a permit
   * with a zero address signature.
   * Refers to the hardhat test with the description 'should fail for zero address signature'
   */
  function testPermitZeroAddressSignatureRevert() public {
    //TODO see, for me not work fine, 0x1b always rever for zerdo address
    vm.expectRevert(bytes(ErrorConstants.ERC20_ZERO_ADDRESS_SIGNER_ERROR_MSG));
    holographERC20.permit(deployer, alice, initialValue, goodDeadLine, uint8(0x1b), signature, signature);
  }

  /**
   * @notice Verifies that attempting a permit with an invalid v-value in the signature fails
   * @dev This test expects a revert with the message "ERC20: invalid v-value" when trying to execute a permit with
   * an invalid v-value in the signature.
   * Refers to the hardhat test with the description 'should fail for invalid signature v value'
   */
  function testPermitInvalidSignatureV_ValueRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ERC20_INVALID_V_VALUE_ERROR_MSG));
    holographERC20.permit(deployer, alice, initialValue, goodDeadLine, uint8(0x04), zeroSignature, zeroSignature);
  }

  /**
   * @notice Verifies that attempting a permit with an invalid signature fails
   * @dev This test expects a revert with the message "ERC20: invalid signature" when trying to execute a permit with
   * an invalid signature.
   * Refers to the hardhat test with the description 'should fail for invalid signature'
   */
  function testPermitInvalidSignatureRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ERC20_INVALID_SIGNATURE_ERROR_MSG));
    vm.prank(deployer);
    holographERC20.permit(deployer, alice, initialValue, goodDeadLine, uint8(0x1b), signature2, signature3);
  }

  /**
   * @notice Verifies that executing a permit with a valid signature succeeds
   * @dev This test creates a permit with a valid signature, calculates the digest, signs the digest, and then
   * executes the permit.
   * Refers to the hardhat test with the description 'should succeed for valid signature'
   */
  function testValidSignature() public {
    PermitSigUtils.Permit memory permit = PermitSigUtils.Permit({
      owner: deployer,
      spender: alice,
      value: maxValue,
      nonce: holographERC20.nonces(alice),
      deadline: goodDeadLine
    });
    bytes32 digest = permitSigUtils.getTypedDataHash(permit);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, digest);
    vm.expectEmit(true, true, false, true);
    emit Approval(deployer, alice, maxValue);
    holographERC20.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
  }

  /**
   * @notice Verifies that the allowance is updated correctly after executing a permit
   * @dev This test first executes a permit with a valid signature and then checks if the allowance is updated correctly.
   * There is no hardhat version of this test.
   */
  function testPermitAllowance() public {
    testValidSignature();
    assertEq(holographERC20.allowance(deployer, alice), maxValue);
  }

  /**
   * @notice Verifies that the nonce is updated correctly after executing a permit
   * @dev This test first executes a permit with a valid signature and then checks if the nonce is updated correctly.
   * There is no hardhat version of this test.
   */
  function testPermitNonces() public {
    testValidSignature();
    assertEq(holographERC20.nonces(deployer), 1);
  }

  /* -------------------------------------------------------------------------- */
  /*                        ERC20 TEST   Ownership tests                        */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Verifies that the owner of the contract is the deployer
   * @dev This test checks if the owner of the contract is the deployer.
   * Refers to the hardhat test with the description 'should return deployer address'
   */
  function testOwner() public view {
    assertEq(holographERC20.owner(), deployer);
  }

  /**
   * @notice Verifies that the contract recognizes the deployer as the owner
   * @dev This test simulates the deployer and checks if the contract recognizes the deployer as the owner.
   * Refers to the hardhat test with the description 'deployer should return true for isOwner'
   */
  function testIsOwner() public {
    vm.prank(deployer);
    assertEq(sampleERC20.isOwner(), true);
  }

  /**
   * @notice Verifies that the contract does not recognize Alice as the owner
   * @dev This test simulates Alice as the transaction sender and checks if the contract does not recognize Alice as the owner.
   * Refers to the hardhat test with the description 'wallet1 should return false for isOwner',
   */
  function testIsOwnerFalse() public {
    vm.prank(alice);
    assertEq(sampleERC20.isOwner(), false);
  }

  /**
   * @notice Verifies that the ERC20 contract's owner proxy is the admin address
   * @dev This test checks if the owner proxy of the ERC20 contract is the address of the admin.
   * Refers to the hardhat test with the description 'should return "HolographFactoryProxy" address'
   */
  function testErc20GetOwnerProxy() public view {
    assertEq(holographERC20.getOwner(), address(admin));
  }

  /**
   * @notice Verifies that the ERC20 contract prevents non-owner Alice from changing the owner
   * @dev This test simulates Alice and attempts to change the owner of the ERC20 contract, which should revert with
   * an "owner only function" error.
   * Refers to the hardhat test with the description 'deployer should fail transferring ownership'
   */
  function testErc20DeployerTransferOwnerRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ONLY_OWNER_ERROR_MSG));
    vm.prank(alice);
    holographERC20.setOwner(alice);
  }

  /**
   * @notice Verifies that the ERC20 contract allows the deployer to change the owner
   * @dev This test simulates the deployer and attempts to change the owner of the ERC20 contract using the adminCall function.
   * Refers to the hardhat test with the description 'deployer should set owner to deployer'
   */
  function testErc20DeployerTransferOwner() public {
    bytes memory data = abi.encodeWithSelector(bytes4(keccak256("setOwner(address)")), deployer);
    vm.expectEmit(true, true, false, false);
    emit OwnershipTransferred(address(admin), address(deployer));
    vm.prank(deployer);
    admin.adminCall(address(holographERC20), data);
  }

  /**
   * @notice Verifies that the ERC20 contract allows the new owner to change the owner again
   * @dev This test simulates the deployer and transfers ownership to the admin. Then, it verifies that the admin
   * can change the owner again.
   * Refers to the hardhat test with the description 'deployer should transfer ownership to "HolographFactoryProxy"'
   */
  function testTransferOwnership() public {
    testErc20DeployerTransferOwner();
    vm.expectEmit(true, true, false, true);
    emit OwnershipTransferred(address(deployer), address(admin));
    vm.prank(deployer);
    holographERC20.setOwner(address(admin));
  }

  /* -------------------------------------------------------------------------- */
  /*                             ERC20 TEST    Admin                            */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice Verifies that the ERC20 contract's admin is set correctly
   * @dev This test checks if the admin of the ERC20 contract is set to the admin address.
   * Refers to the hardhat test with the description 'admin() should return "HolographFactoryProxy" address'
   */
  function testErc20Admin() public view {
    assertEq(holographERC20.admin(), address(admin));
  }

  /**
   * @notice Verifies that the ERC20 contract's getAdmin function returns the correct address
   * @dev This test checks if the getAdmin function of the ERC20 contract returns the admin address.
   * Refers to the hardhat test with the description 'getAdmin() should return "HolographFactoryProxy" address'
   */
  function testErc20GetAdmin() public view {
    assertEq(holographERC20.getAdmin(), address(admin));
  }

  /**
   * @notice Verifies that the ERC20 contract prevents non-admin Alice from changing the admin
   * @dev This test simulates Alice and attempts to change the admin of the ERC20 contract, which should revert with
   * an "admin only function" error.
   * Refers to the hardhat test with the description 'wallet1 should fail setting admin'
   */
  function testErc20SetAdminRevert() public {
    vm.expectRevert(bytes(ErrorConstants.ONLY_ADMIN_ERROR_MSG));
    vm.prank(alice);
    holographERC20.setAdmin(address(admin));
  }

  /**
   * @notice Verifies that the ERC20 contract allows the deployer to change the admin using the adminCall function
   * @dev This test simulates the deployer and attempts to change the admin of the ERC20 contract using the adminCall function.
   * Refers to the hardhat test with the description 'deployer should succeed setting admin via "HolographFactoryProxy"'
   */
  function testErc20DeployerSetAdminByProxy() public {
    bytes memory data = abi.encodeWithSelector(bytes4(keccak256("setAdmin(address)")), deployer);
    vm.prank(deployer);
    admin.adminCall(address(holographERC20), data);
    assertEq(holographERC20.admin(), address(deployer));
  }
}
