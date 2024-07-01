// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Constants} from "../utils/Constants.sol";
import {HolographERC20} from "../../../src/enforcer/HolographERC20.sol";
import {Holograph} from "../../../src/Holograph.sol";
import {Faucet} from "../../../src/faucet/Faucet.sol";
import {ERC20} from "../../../src/interface/ERC20.sol";

/**
 * @title Testing the Faucet
 * @notice Suite of unit tests for the Faucet contract
 * @dev Translation of a suite of Hardhat tests found in test/08_faucet_tests.ts
 */
contract FaucetTest is Test {
  uint256 localHostFork;
  string LOCALHOST_RPC_URL = vm.envString("LOCALHOST_RPC_URL");

  HolographERC20 holographERC20;
  Holograph holograph;
  Faucet faucet;
  uint256 DEFAULT_DRIP_AMOUNT = 100 ether;
  uint256 DEFAULT_COOLDOWN = 24 hours;
  uint256 INITIAL_FAUCET_FUNDS = DEFAULT_DRIP_AMOUNT * 20;
  uint256 FAUCET_PREFUND_AMOUNT;

  // Revert msgs
  string REVERT_INITIALIZED = "Faucet contract is already initialized";
  string REVERT_COME_BACK_LATER = "Come back later";
  string REVERT_NOT_AN_OWNER = "Caller is not the owner";

  address deployer = vm.addr(Constants.getPKDeployer());
  address alice = vm.addr(1);
  address bob = vm.addr(2);

  /**
   * @notice Sets up the environment for testing the Holograph Factory
   * @dev This function performs the following steps:
   *      1. Creates a local host fork and selects the created fork.
   *      2. Retrieves the Holograph and HolographERC20 contracts
   *      3. Deploys a new Faucet contract and initializes it with the deployer and HolographERC20 addresses
   *      4. Stores the initial balance of the Faucet contract in the `FAUCET_PREFUND_AMOUNT` variable
   *      5. Transfers additional funds to the Faucet contract using the HolographERC20 contract
   */
  function setUp() public {
    vm.startPrank(deployer);
    localHostFork = vm.createFork(LOCALHOST_RPC_URL);
    vm.selectFork(localHostFork);
    holograph = Holograph(payable(Constants.getHolograph()));
    holographERC20 = HolographERC20(payable(holograph.getUtilityToken()));
    faucet = new Faucet();
    faucet.init(abi.encode(address(deployer), address(holographERC20)));
    FAUCET_PREFUND_AMOUNT = holographERC20.balanceOf(address(faucet));
    holographERC20.transfer(address(faucet), INITIAL_FAUCET_FUNDS);
    vm.stopPrank();
  }

  /* -------------------------------------------------------------------------- */
  /*                                INIT Section                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice This function tests the `init` function of the `Faucet` contract. Initialize the contract
   * @dev This test checks that the initializer function of the Faucet contract reverts when called.
   * It expects the function to revert with the `Faucet contract is already initialized` error message.
   * Refers to the hardhat test with the description 'should fail initializing already initialized Faucet'
   */
  function testInitializerRevert() public {
    vm.expectRevert(bytes(REVERT_INITIALIZED));
    faucet.init(abi.encode(address(deployer), address(holographERC20)));
  }

  /* -------------------------------------------------------------------------- */
  /*                                DRIP Section                                */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice This function tests the `isAllowedToWithdraw` function of the `Faucet` contract. User is allowed to withdraw
   * @dev This test checks that the `isAllowedToWithdraw` function of the Faucet contract allows withdrawal.
   * It calls the function with an arbitrary user address and checks that it returns `true`.
   * Refers to the hardhat test with the description 'isAllowedToWithdraw(): User is allowed to withdraw for the first time'
   */
  function testIsAllowToWithdraw() public {
    faucet.isAllowedToWithdraw(alice);
  }

  /**
   * @notice This function tests the `requestTokens` function of the `Faucet` contract. User can withdraw token
   * @dev This test checks that the `requestTokens` function of the Faucet contract allows token requests.
   * Call `requestTokens` function with arbitrary user.
   * Refers to the hardhat test with the description 'requestTokens(): User can withdraw for the first time'
   */
  function testRequestToken() public {
    vm.prank(alice);
    faucet.requestTokens();
  }

  /**
   * @notice This function tests the `requestTokens` function of the `Faucet` contract. User cannot is not allow to
   * withdraw token twice
   * @dev This test first calls the `testRequestToken` function to simulate a token request.
   * It then checks that the `isAllowedToWithdraw` function returns `false`, indicating that withdrawal is not
   * allowed after a recent token request.
   * Refers to the hardhat test with the description 'isAllowedToWithdraw(): User is not allowed to withdraw for the second time'
   */
  function testIsAllowToWithdrawRevert() public {
    testRequestToken();
    assertEq(faucet.isAllowedToWithdraw(alice), false);
  }

  /**
   * @notice This function tests the `requestTokens` function of the `Faucet` contract. User cannot withdraw token twice
   * @dev This test checks that the `requestTokens` function of the Faucet contract reverts when called.
   * It first calls the `testRequestToken` function to simulate a token request.
   * It then calls the `requestTokens` function again with an arbitrary address and expects the function to revert.
   * Refers to the hardhat test with the description 'requestTokens(): User cannot withdraw for the second time'
   */
  function testRequestTokenRevert() public {
    testRequestToken();
    vm.expectRevert();
    vm.prank(alice);
    faucet.requestTokens();
  }

  /* -------------------------------------------------------------------------- */
  /*                             OWNER DRIP Section                             */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice This function tests the `grantTokens` function of the `Faucet` contract. Owner can grant tokens
   * @dev This test checks that the `grantTokens` function of the Faucet contract grants tokens to the specified address.
   * It pranks as the deployer and calls the `grantTokens` function with the an arbitrary user address.
   * The test then asserts that this address has the default drip amount of tokens.
   * Refers to the hardhat test with the description 'grantTokens(): Owner can grant tokens'
   */
  function testGrantToken() public {
    vm.prank(deployer);
    faucet.grantTokens(alice);
    assertEq(holographERC20.balanceOf(alice), DEFAULT_DRIP_AMOUNT);
  }

  /**
   * @notice This function tests the `grantTokens` function of the `Faucet` contract. Owner can grant tokens
   * with arbitrary amount
   * @dev This test checks that the `grantTokens` function of the Faucet contract grants a specific amount of
   * tokens to the specified address.
   * It pranks as the deployer and calls the `grantTokens` function with an arbitrary address and a specific amount of tokens.
   * The test then asserts that this address has the specified amount of tokens.
   * Refers to the hardhat test with the description 'grantTokens(): Owner can grant tokens again with arbitrary amount'
   */
  function testGrantTokenSpecificAmount() public {
    vm.prank(deployer);
    faucet.grantTokens(alice, 5);
    assertEq(holographERC20.balanceOf(alice), 5);
  }

  /**
   * @notice This function tests the `grantTokens` function of the `Faucet` contract. Revert because not owner call
   * @dev This test checks that the `grantTokens` function of the Faucet contract reverts when called without
   * the necessary authorization.
   * It expects the function to revert without any specific error message.
   * Refers to the hardhat test with the description 'grantTokens(): Non Owner should fail to grant tokens'
   */
  function testGrantTokenRevert() public {
    vm.expectRevert();
    faucet.grantTokens(alice);
  }

  /**
   * @notice This function tests the `grantTokens` function of the `Faucet` contract. Revert because not have founds
   * @dev This test checks that the `grantTokens` function of the Faucet contract reverts when called with insufficient funds.
   * It pranks as the deployer and calls the `grantTokens` function with an arbitrary address and the initial faucet funds.
   * The test then expects the function to revert with the error message "Faucet is empty".
   * Refers to the hardhat test with the description 'grantTokens(): Should fail if contract has insufficient funds'
   */
  function testGrantTokenRevertInsufficientFounds() public {
    vm.prank(deployer);
    faucet.grantTokens(alice, INITIAL_FAUCET_FUNDS);
    vm.expectRevert("Faucet is empty");
    vm.prank(deployer);
    faucet.grantTokens(alice);
  }

  /* -------------------------------------------------------------------------- */
  /*                       OWNER ADJUST Withdraw Cooldown                       */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice This function tests the `setWithdrawCooldown` function of the `Faucet` contract.
   * Owner can adjust Withdraw Cooldown
   * @dev This test checks that the `isAllowedToWithdraw` function of the Faucet contract returns `false` when
   * the owner tries to withdraw tokens twice.
   * It pranks as the deployer and requests tokens. Then, it asserts that the owner is not allowed to withdraw tokens.
   * Refers to the hardhat test with the description 'isAllowedToWithdraw(): Owner is not allowed to withdraw'
   */
  function testOwnerIsNotAllowedToWithdrawTwice() public {
    vm.prank(deployer);
    faucet.requestTokens();
    assertEq(faucet.isAllowedToWithdraw(deployer), false);
  }

  /**
   * @notice This function tests the `setWithdrawCooldown` function of the `Faucet` contract.
   * Owner can adjust Withdraw Cooldown in Zero
   * @dev This test checks that the `setWithdrawCooldown` function of the Faucet contract sets the cooldown to zero.
   * It pranks as the deployer and calls the `setWithdrawCooldown` function with the value zero.
   * The test then asserts that the cooldown is set to zero.
   * Refers to the hardhat test with the description 'setWithdrawCooldown(): Owner adjusts Withdraw Cooldown to 0 seconds'
   */
  function testSetCooldownInZero() public {
    vm.prank(deployer);
    faucet.setWithdrawCooldown(0);
    assertEq(faucet.faucetCooldown(), 0);
  }

  /**
   * @notice This function tests the `setWithdrawCooldown` function of the `Faucet` contract.
   * Owner can adjust Withdraw Cooldown in Zero and allow too withdraw
   * @dev This test first calls the `testOwnerIsNotAllowedToWithdrawTwice` function to ensure
   * the owner is not allowed to withdraw twice.
   * It then calls the `testSetCooldownInZero` function to set the cooldown to zero. Finally,
   * it asserts that the owner is now allowed to withdraw again.
   * Refers to the hardhat test with the description 'isAllowedToWithdraw(): Owner is allowed to withdraw'
   */
  function testSetCooldownInZeroAndAllowTooWithdraw() public {
    testOwnerIsNotAllowedToWithdrawTwice();
    testSetCooldownInZero();
    assertEq(faucet.isAllowedToWithdraw(deployer), true);
  }

  /**
   * @notice This function tests the `setWithdrawCooldown` function of the `Faucet` contract.
   * Not owner can't adjust Withdraw Cooldown
   * @dev This test checks that the `setWithdrawCooldown` function of the Faucet contract reverts when called by a non-owner.
   * It expects the function to revert with the `Caller is not the owner` error message.
   * Refers to the hardhat test with the description 'setWithdrawCooldown(): User can't adjust Withdraw Cooldown'
   */
  function testSetCooldownRevert() public {
    vm.expectRevert(bytes(REVERT_NOT_AN_OWNER));
    faucet.setWithdrawCooldown(0);
  }

  /* -------------------------------------------------------------------------- */
  /*                        OWNER ADJUST Withdraw Amount                        */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice This function tests the `setWithdrawAmount` function of the `Faucet` contract. Owner can adjust Withdraw Amount
   * @dev This test checks that the `setWithdrawAmount` function of the Faucet contract changes the withdraw amount.
   * It pranks as the deployer and sets a specific withdrawal amount..
   * The test then asserts that the withdraw amount corresponds to the one set in the previous step.
   * Refers to the hardhat test with the description 'setWithdrawAmount(): Owner adjusts Withdraw Amount'
   */
  function testChangeWithdrawAmount() public {
    vm.prank(deployer);
    faucet.setWithdrawAmount(DEFAULT_DRIP_AMOUNT - 2);
    assertEq(faucet.faucetDripAmount(), DEFAULT_DRIP_AMOUNT - 2);
  }

  /**
   * @notice This function tests the `setWithdrawAmount` function of the `Faucet` contract. User can withdraw increased amount
   * @dev This test checks that changing the withdraw amount and requesting tokens with the new amount works correctly.
   * It first calls the `testChangeWithdrawAmount` function to set the new withdraw amount.
   * Then, it calls the `testRequestToken` function to request tokens with the new amount.
   * Finally, it asserts that the balance of the requested tokens is set to the new withdraw amount.
   * Refers to the hardhat test with the description 'requestTokens(): User can withdraw increased amount'
   */
  function testChangeWithdrawAmountAndRequestToken() public {
    //set the new amount with DEFAULT_DRIP_AMOUNT -2
    testChangeWithdrawAmount();
    // alice request token with the new amount
    testRequestToken();
    assertEq(holographERC20.balanceOf(alice), DEFAULT_DRIP_AMOUNT - 2);
  }

  /**
   * @notice This function tests the `setWithdrawAmount` function of the `Faucet` contract. Not owner can't adjust Withdraw Amount
   * @dev This test checks that the `setWithdrawAmount` function of the Faucet contract reverts when called by a non-owner.
   * It pranks as an arbitrary user and expects the function to revert with the `Caller is not the owner` error message.
   * Refers to the hardhat test with the description 'setWithdrawAmount(): User can't adjust Withdraw Amount'
   */
  function testChangeWithdrawAmountRevert() public {
    vm.prank(alice);
    vm.expectRevert(bytes(REVERT_NOT_AN_OWNER));
    faucet.setWithdrawAmount(DEFAULT_DRIP_AMOUNT - 2);
  }

  /* -------------------------------------------------------------------------- */
  /*                          OWNER can Withdraw funds                          */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice This function tests the `withdrawTokens` function of the `Faucet` contract.
   * Owner can withdraw funds
   * @dev This test checks that the `withdrawTokens` function of the Faucet contract allows the
   *  owner to withdraw tokens to an arbitrary user address.
   * It pranks as the deployer and calls the `withdrawTokens` function with the arbitrary user
   * address and a default drip amount.
   * The test then asserts that the balance of this address is set to the  default drip amount.
   * Refers to the hardhat test with the description 'withdrawTokens()'
   */
  function testWithdrawTokens() public {
    vm.prank(deployer);
    faucet.withdrawTokens(bob, DEFAULT_DRIP_AMOUNT);
    assertEq(holographERC20.balanceOf(bob), DEFAULT_DRIP_AMOUNT);
  }

  /**
   * @notice This function tests the `withdrawTokens` function of the `Faucet` contract. Not owner can't withdraw funds
   * @dev This test checks that the `withdrawTokens` function of the Faucet contract reverts when called by a non-owner.
   * It pranks as an arbitrary user and expects the function to revert with the `Caller is not the owner` error message.
   */
  function testWithdrawTokensRevert() public {
    vm.prank(alice);
    vm.expectRevert(bytes(REVERT_NOT_AN_OWNER));
    faucet.withdrawTokens(bob, DEFAULT_DRIP_AMOUNT);
  }

  /**
   * @notice This function tests the `withdrawAllTokens` function of the `Faucet` contract.
   *  Owner can withdraw all the funds
   * @dev This test checks that the `withdrawAllTokens` function of the Faucet contract allows the
   * owner to withdraw all tokens to an arbitrary address.
   * It pranks as the deployer and calls the `withdrawAllTokens` function with an arbitrary user address.
   * The test then asserts that the balance of this address is set to the initial faucet funds and
   * the balance of the faucet is set to zero.
   * Refers to the hardhat test with the description 'withdrawAllTokens()'
   */
  function testWithdrawAllTokens() public {
    vm.prank(deployer);
    faucet.withdrawAllTokens(bob);
    assertEq(holographERC20.balanceOf(bob), INITIAL_FAUCET_FUNDS);
    assertEq(holographERC20.balanceOf(address(faucet)), 0);
  }

  /**
   * @notice This function tests the `withdrawAllTokens` function of the `Faucet` contract.
   * Not owner can't withdraw all the funds
   * @dev This test checks that the `withdrawAllTokens` function of the Faucet contract reverts
   *  when called by a non-owner.
   * It pranks as an arbitrary user and expects the function to revert with the `Caller is not the owner` error message.
   * Refers to the hardhat test with the description 'withdrawAllTokens()'
   */
  function testWithdrawAllTokensRevert() public {
    vm.prank(alice);
    vm.expectRevert(bytes(REVERT_NOT_AN_OWNER));
    faucet.withdrawAllTokens(bob);
  }
}
