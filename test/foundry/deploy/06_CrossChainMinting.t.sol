// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Constants} from "../utils/Constants.sol";
import {HelperDeploymentConfig} from "../utils/HelperDeploymentConfig.sol";
import {HelperSignEthMessage} from "../utils/HelperSignEthMessage.sol";

import {Holograph} from "../../../src/Holograph.sol";
import {HolographBridge} from "../../../src/HolographBridge.sol";
import {HolographRegistry} from "../../../src/HolographRegistry.sol";
import {HolographFactory} from "../../../src/HolographFactory.sol";
import {HolographOperator, OperatorJob} from "../../../src/HolographOperator.sol";

import {LayerZeroModule, GasParameters} from "../../../src/module/LayerZeroModule.sol";
import {HolographERC20} from "../../../src/enforcer/HolographERC20.sol";
import {Holographer} from "../../../src/enforcer/Holographer.sol";
import {HolographERC721} from "../../../src/enforcer/HolographERC721.sol";
import {SampleERC721} from "../../../src/token/SampleERC721.sol";
import {MockLZEndpoint} from "../../../src/mock/MockLZEndpoint.sol";
import {Verification} from "../../../src/struct/Verification.sol";
import {DeploymentConfig} from "../../../src/struct/DeploymentConfig.sol";
import {SampleERC20} from "../../../src/token/SampleERC20.sol";

contract CrossChainMinting is Test {
  event BridgeableContractDeployed(address indexed contractAddress, bytes32 indexed hash);
  event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
  event FailedOperatorJob(bytes32 jobHash);

  uint256 public chain1;
  uint256 public chain2;
  string public LOCALHOST_RPC_URL = vm.envString("LOCALHOST_RPC_URL");
  string public LOCALHOST2_RPC_URL = vm.envString("LOCALHOST2_RPC_URL");

  address public alice;
  address public operator;

  uint256 privateKeyDeployer = Constants.getPKDeployer();
  address deployer = vm.addr(privateKeyDeployer);

  uint32 holographIdL1 = Constants.getHolographIdL1();
  uint32 holographIdL2 = Constants.getHolographIdL2();

  uint256 constant BLOCKTIME = 60;
  uint256 constant GWEI = 1000000000; // 1 Gwei
  uint256 constant TESTGASLIMIT = 10000000; // Gas limit
  uint256 constant GASPRICE = 1000000000; // 1 Gwei as gas price

  uint224 constant firstTokenIdChain1 = 1;
  uint224 constant secondTokenIdChain1 = 2;
  uint224 constant thirdTokenIdChain1 = 3;

  uint256 constant firstTokenIdChain2 = 115792089156436355422119065624686862592211092644729130771835866564602298892289;
  uint256 constant secondTokenIdChain2 = 115792089156436355422119065624686862592211092644729130771835866564602298892290;
  uint256 constant thirdTokenIdChain2 = 115792089156436355422119065624686862592211092644729130771835866564602298892291;

  uint256 msgBaseGas;
  uint256 msgGasPerByte;
  uint256 jobBaseGas;
  uint256 jobGasPerByte;

  Holograph holographChain1;
  Holograph holographChain2;
  HolographOperator holographOperatorChain1;
  HolographOperator holographOperatorChain2;
  Holographer utilityTokenHolographerChain1;
  Holographer utilityTokenHolographerChain2;
  MockLZEndpoint mockLZEndpointChain1;
  MockLZEndpoint mockLZEndpointChain2;
  HolographFactory holographFactoryChain1;
  HolographFactory holographFactoryChain2;
  HolographBridge holographBridgeChain1;
  HolographBridge holographBridgeChain2;
  LayerZeroModule lzModuleChain1;
  LayerZeroModule lzModuleChain2;
  Holographer sampleErc721HolographerChain1;
  Holographer sampleErc721HolographerChain2;
  HolographERC721 sampleErc721EnforcerChain1;
  HolographERC721 sampleErc721EnforcerChain2;
  HolographERC20 HLGCHAIN1;
  HolographERC20 HLGCHAIN2;

  HolographRegistry holographRegistryChain1;
  HolographRegistry holographRegistryChain2;

  struct EstimatedGas {
    bytes payload;
    uint256 estimatedGas;
    uint256 fee;
    uint256 hlgFee;
    uint256 msgFee;
    uint256 dstGasPrice;
  }

  /**
   * @notice Get the gas cost for a message with payload in the local chain
   * @param _payload The payload of the message
   * @return The total gas cost for the message
   */
  function getLzMsgGas(bytes memory _payload) public view returns (uint256) {
    uint256 totalGas = msgBaseGas + (_payload.length * msgGasPerByte);
    return totalGas;
  }

  /**
   * @notice Get the gas cost for a message with payload in the holograph job
   * @param _gasLimit The gas limit for the message
   * @param _payload The payload of the message
   * @return The total gas cost for the message
   */
  function getHlgMsgGas(uint256 _gasLimit, bytes memory _payload) public view returns (uint256) {
    uint256 totalGas = _gasLimit + jobBaseGas + (_payload.length * jobGasPerByte);
    return totalGas;
  }

  /**
   * @notice Get the request payload for a bridge out request
   * @param _target The target address for the request
   * @param _data The data for the request
   * @param isL1 Flag indicating if the request is for chain 1 (localhost)
   * @return The request payload
   */
  function getRequestPayload(address _target, bytes memory _data, bool isL1) public returns (bytes memory) {
    if (isL1) {
      vm.selectFork(chain1);
      vm.prank(deployer);
      return
        holographBridgeChain1.getBridgeOutRequestPayload(
          holographIdL2,
          _target,
          type(uint256).max,
          type(uint256).max,
          _data
        );
    } else {
      vm.selectFork(chain2);
      vm.prank(deployer);
      return
        holographBridgeChain2.getBridgeOutRequestPayload(
          holographIdL1,
          _target,
          type(uint256).max,
          type(uint256).max,
          _data
        );
    }
  }

  /**
   * @dev Get estimated gas for a cross-chain transaction.
   * @param _target The target contract address.
   * @param _data The transaction data.
   * @param _payload The payload data.
   * @param isL1 Flag indicating if the transaction is on chain1 (true) or chain2 (false).
   * @param _gasLimitAddition The additional gas limit.
   * @return The estimated gas and fee information.
   */
  function getEstimatedGas(
    address _target,
    bytes memory _data,
    bytes memory _payload,
    bool isL1,
    uint256 _gasLimitAddition
  ) public returns (EstimatedGas memory) {
    if (isL1) {
      // Select chain2 fork
      vm.selectFork(chain2);
      // Call holographOperatorChain2.jobEstimator to get job estimator gas
      (, bytes memory result) = address(holographOperatorChain2).call{gas: TESTGASLIMIT}(
        abi.encodeWithSelector(holographOperatorChain2.jobEstimator.selector, _payload)
      );
      uint256 jobEstimatorGas = abi.decode(result, (uint256));

      // Calculate estimated gas
      uint256 estimatedGas = TESTGASLIMIT - jobEstimatorGas + _gasLimitAddition;

      // Select chain1 fork
      vm.selectFork(chain1);
      vm.prank(deployer);
      // Get bridge out request payload
      bytes memory payload = holographBridgeChain1.getBridgeOutRequestPayload(
        holographIdL2,
        _target,
        estimatedGas,
        GWEI,
        _data
      );

      // Get message fee
      (uint256 fee1, uint256 fee2, uint256 fee3) = holographBridgeChain1.getMessageFee(
        holographIdL2,
        estimatedGas,
        GWEI,
        payload
      );

      uint256 total = fee1 + fee2;

      // Select chain2 fork
      vm.selectFork(chain2);
      // Call holographOperatorChain2.jobEstimator to get job estimator gas
      (, bytes memory result2) = address(holographOperatorChain2).call{gas: TESTGASLIMIT, value: total}(
        abi.encodeWithSelector(holographOperatorChain2.jobEstimator.selector, payload)
      );

      uint256 jobEstimatorGas2 = abi.decode(result2, (uint256));

      estimatedGas = TESTGASLIMIT - jobEstimatorGas2 + _gasLimitAddition;

      // Calculate HLG message gas
      estimatedGas = getHlgMsgGas(estimatedGas, payload);

      return
        EstimatedGas({
          payload: payload,
          estimatedGas: estimatedGas,
          fee: total,
          hlgFee: fee1,
          msgFee: fee2,
          dstGasPrice: fee3
        });
    } else {
      // Select chain1 fork
      vm.selectFork(chain1);
      // Call holographOperatorChain1.jobEstimator to get job estimator gas
      (, bytes memory result) = address(holographOperatorChain1).call{gas: TESTGASLIMIT}(
        abi.encodeWithSelector(holographOperatorChain1.jobEstimator.selector, _payload)
      );
      uint256 jobEstimatorGas = abi.decode(result, (uint256));

      // Calculate estimated gas
      uint256 estimatedGas = TESTGASLIMIT - jobEstimatorGas + _gasLimitAddition;

      // Select chain2 fork
      vm.selectFork(chain2);
      vm.prank(deployer);
      // Get bridge out request payload
      bytes memory payload = holographBridgeChain2.getBridgeOutRequestPayload(
        holographIdL1,
        _target,
        estimatedGas,
        GWEI,
        _data
      );

      // Get message fee
      (uint256 fee1, uint256 fee2, uint256 fee3) = holographBridgeChain2.getMessageFee(
        holographIdL1,
        estimatedGas,
        GWEI,
        payload
      );

      uint256 total = fee1 + fee2;

      // Select chain1 fork
      vm.selectFork(chain1);
      // Call holographOperatorChain1.jobEstimator to get job estimator gas
      (, bytes memory result2) = address(holographOperatorChain1).call{gas: TESTGASLIMIT, value: total}(
        abi.encodeWithSelector(holographOperatorChain1.jobEstimator.selector, payload)
      );

      uint256 jobEstimatorGas2 = abi.decode(result2, (uint256));

      estimatedGas = TESTGASLIMIT - jobEstimatorGas2 + _gasLimitAddition;

      // Calculate HLG message gas
      estimatedGas = getHlgMsgGas(estimatedGas, payload);

      return
        EstimatedGas({
          payload: payload,
          estimatedGas: estimatedGas,
          fee: total,
          hlgFee: fee1,
          msgFee: fee2,
          dstGasPrice: fee3
        });
    }
  }

  function setUp() public {
    chain1 = vm.createFork(LOCALHOST_RPC_URL);
    chain2 = vm.createFork(LOCALHOST2_RPC_URL);

    alice = vm.addr(1);
    operator = vm.addr(2);

    vm.selectFork(chain1);
    holographChain1 = Holograph(payable(Constants.getHolograph()));
    holographOperatorChain1 = HolographOperator(payable(Constants.getHolographOperatorProxy()));
    holographRegistryChain1 = HolographRegistry(payable(Constants.getHolographRegistryProxy()));
    mockLZEndpointChain1 = MockLZEndpoint(payable(Constants.getMockLZEndpoint()));
    holographFactoryChain1 = HolographFactory(payable(Constants.getHolographFactoryProxy()));
    holographBridgeChain1 = HolographBridge(payable(Constants.getHolographBridgeProxy()));
    lzModuleChain1 = LayerZeroModule(payable(Constants.getLayerZeroModuleProxy()));
    (, bytes32 erc721ConfigHash1) = getConfigSampleERC721(true);
    address sampleErc721HolographerChain1Address = holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash1);
    sampleErc721HolographerChain1 = Holographer(payable(sampleErc721HolographerChain1Address));
    sampleErc721EnforcerChain1 = HolographERC721(payable(sampleErc721HolographerChain1.getHolographEnforcer()));
    HLGCHAIN1 = HolographERC20(payable(Constants.getHolographUtilityToken()));

    GasParameters memory gasParams = lzModuleChain1.getGasParameters(holographIdL1);
    msgBaseGas = gasParams.msgBaseGas;
    msgGasPerByte = gasParams.msgGasPerByte;
    jobBaseGas = gasParams.jobBaseGas;
    jobGasPerByte = gasParams.jobGasPerByte;

    vm.selectFork(chain2);
    holographChain2 = Holograph(payable(Constants.getHolograph()));
    holographOperatorChain2 = HolographOperator(payable(Constants.getHolographOperatorProxy()));
    holographRegistryChain2 = HolographRegistry(payable(Constants.getHolographRegistryProxy()));
    mockLZEndpointChain2 = MockLZEndpoint(payable(Constants.getMockLZEndpoint()));
    holographFactoryChain2 = HolographFactory(payable(Constants.getHolographFactoryProxy()));
    holographBridgeChain2 = HolographBridge(payable(Constants.getHolographBridgeProxy()));
    lzModuleChain2 = LayerZeroModule(payable(Constants.getLayerZeroModuleProxy()));
    (, bytes32 erc721ConfigHash2) = getConfigSampleERC721(false);
    address sampleErc721HolographerChain2Address = holographRegistryChain2.getHolographedHashAddress(erc721ConfigHash2);
    sampleErc721HolographerChain2 = Holographer(payable(sampleErc721HolographerChain2Address));
    sampleErc721EnforcerChain2 = HolographERC721(payable(sampleErc721HolographerChain2.getHolographEnforcer()));
    HLGCHAIN2 = HolographERC20(payable(Constants.getHolographUtilityToken()));

    addOperator(operator);
  }

  // Enable operators for chain1 and chain2

  /**
   * @notice Add an operator to the contract
   * @param _operator The address of the operator to be added
   */
  function addOperator(address _operator) public {
    vm.selectFork(chain1);
    (uint256 bondAmount, ) = holographOperatorChain1.getPodBondAmounts(1);

    vm.selectFork(chain1);
    vm.prank(deployer);
    HLGCHAIN1.transfer(_operator, bondAmount);
    vm.startPrank(_operator);
    HLGCHAIN1.approve(address(holographOperatorChain1), bondAmount);
    holographOperatorChain1.bondUtilityToken(_operator, bondAmount, 1);
    vm.stopPrank();

    vm.selectFork(chain2);
    vm.prank(deployer);
    HLGCHAIN2.transfer(_operator, bondAmount);
    vm.startPrank(_operator);
    HLGCHAIN2.approve(address(holographOperatorChain2), bondAmount);
    holographOperatorChain2.bondUtilityToken(_operator, bondAmount, 1);
    vm.stopPrank();
  }

  /**
   * @notice should add 10 operator wallets for each chain
   * @dev Adds 10 operator wallets for each chain
   */
  function testShouldAdd10OperatorsForEachChain() public {
    address[] memory wallets = new address[](10); // Array to hold operator addresses

    // generate 10 operator wallets
    for (uint i = 0; i < 10; i++) {
      wallets[i] = address(uint160(uint(keccak256(abi.encodePacked(block.timestamp, i)))));
    }

    for (uint i = 0; i < wallets.length; i++) {
      addOperator(wallets[i]);
    }
  }

  /**
   * @notice Get the configuration for SampleERC20 contract
   * @dev Returns the deployment configuration and hash for SampleERC20 contract
   * @param isL1 Boolean indicating if it's chain1 or chain2
   * @return deployConfig The deployment configuration for SampleERC20 contract
   * @return hashSampleERC20 The hash of the deployment configuration for SampleERC20 contract
   */
  function getConfigSampleERC20(
    bool isL1
  ) public view returns (DeploymentConfig memory deployConfig, bytes32 hashSampleERC20) {
    deployConfig = HelperDeploymentConfig.getERC20(
      isL1 ? Constants.getHolographIdL1() : Constants.getHolographIdL2(),
      vm.getCode("SampleERC20.sol:SampleERC20"),
      isL1
    );

    hashSampleERC20 = HelperDeploymentConfig.getDeployConfigHash(deployConfig, deployer);
    return (deployConfig, hashSampleERC20);
  }

  /**
   * @notice Get the configuration for SampleERC721 contract
   * @dev Returns the deployment configuration and hash for SampleERC721 contract
   * @param isL1 Boolean indicating if it's chain1 or chain2
   * @return deployConfig The deployment configuration for SampleERC721 contract
   * @return hashSampleERC721 The hash of the deployment configuration for SampleERC721 contract
   */
  function getConfigSampleERC721(
    bool isL1
  ) public view returns (DeploymentConfig memory deployConfig, bytes32 hashSampleERC721) {
    deployConfig = HelperDeploymentConfig.getERC721(
      isL1 ? Constants.getHolographIdL1() : Constants.getHolographIdL2(),
      vm.getCode("SampleERC721.sol:SampleERC721"),
      Constants.eventConfig,
      isL1
    );

    hashSampleERC721 = HelperDeploymentConfig.getDeployConfigHash(deployConfig, deployer);
    return (deployConfig, hashSampleERC721);
  }

  /**
   * @notice Get the configuration for CxipERC721 contract
   * @dev Returns the deployment configuration and hash for CxipERC721 contract
   * @param isL1 Boolean indicating if it's chain1 or chain2
   * @return deployConfig The deployment configuration for CxipERC721 contract
   * @return hashSampleERC721 The hash of the deployment configuration for CxipERC721 contract
   */
  function getConfigCxipERC721(
    bool isL1
  ) public view returns (DeploymentConfig memory deployConfig, bytes32 hashSampleERC721) {
    deployConfig = HelperDeploymentConfig.getCxipERC721(
      isL1 ? Constants.getHolographIdL1() : Constants.getHolographIdL2(),
      vm.getCode("CxipERC721Proxy.sol:CxipERC721Proxy"),
      Constants.eventConfig,
      isL1
    );

    hashSampleERC721 = HelperDeploymentConfig.getDeployConfigHash(deployConfig, deployer);
    return (deployConfig, hashSampleERC721);
  }

  /**
   * @notice Get the configuration for hTokenETH contract
   * @dev Returns the deployment configuration and hash for hTokenETH contract
   * @param isL1 Boolean indicating if it's chain1 or chain2
   * @return deployConfig The deployment configuration for hTokenETH contract
   * @return hashHtokenTest The hash of the deployment configuration for hTokenETH contract
   */
  function getConfigHtokenETH(
    bool isL1
  ) private returns (DeploymentConfig memory deployConfig, bytes32 hashHtokenTest) {
    string memory tokenName = string.concat("Holographed TestToken chain ", ((isL1) ? "one" : "two"));

    deployConfig = HelperDeploymentConfig.getDeployConfigERC20(
      Constants.hTokenHash,
      (isL1) ? Constants.getHolographIdL1() : Constants.getHolographIdL2(),
      vm.getCode("hTokenProxy.sol:hTokenProxy"),
      tokenName,
      "hTTC1",
      Constants.EMPTY_BYTES32,
      tokenName,
      HelperDeploymentConfig.getInitCodeHtokenETH()
    );
    hashHtokenTest = HelperDeploymentConfig.getDeployConfigHash(deployConfig, Constants.getDeployer());

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      Constants.getPKDeployer(),
      HelperSignEthMessage.toEthSignedMessageHash(hashHtokenTest)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    if ((isL1)) {
      vm.selectFork(chain1);
      holographFactoryChain1.deployHolographableContract(deployConfig, signature, Constants.getDeployer());
    } else {
      vm.selectFork(chain2);
      holographFactoryChain2.deployHolographableContract(deployConfig, signature, Constants.getDeployer());
    }

    return (deployConfig, hashHtokenTest);
  }

  /**
   * SampleERC20
   */

  /**
   * @notice deploy chain1 equivalent on chain2
   * @dev deploy the SampleERC20 equivalent on chain2 and check if it's deployed
   */
  function testSampleERC20Chain2() public {
    (DeploymentConfig memory erc20Config, bytes32 erc20ConfigHash) = getConfigSampleERC20(true);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc20ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain2);
    address sampleErc20Address = holographRegistryChain2.getHolographedHashAddress(erc20ConfigHash);

    assertEq(sampleErc20Address, address(0), "ERC20 contract not deployed on chain2");

    vm.selectFork(chain1);
    sampleErc20Address = holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash);

    vm.selectFork(chain2);
    bytes memory data = abi.encode(erc20Config, signature, deployer);

    address originalMessagingModule = holographOperatorChain2.getMessagingModule();

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(Constants.getMockLZEndpoint());

    bytes memory payload = getRequestPayload(Constants.getHolographFactoryProxy(), data, true);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      Constants.getHolographFactoryProxy(),
      data,
      payload,
      true,
      150000
    );

    payload = estimatedGas.payload;

    (bool success, ) = address(mockLZEndpointChain2).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain2.crossChainMessage.selector,
        address(holographOperatorChain2),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(sampleErc20Address, erc20ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, payload)
    );

    assertEq(
      sampleErc20Address,
      holographRegistryChain2.getHolographedHashAddress(erc20ConfigHash),
      "ERC20 contract not deployed on chain2"
    );
  }

  /**
   * @notice deploy chain2 equivalent on chain1
   * @dev deploy the SampleERC20 equivalent on chain1 and check if it's deployed
   */
  function testSampleERC20Chain1() public {
    (DeploymentConfig memory erc20Config, bytes32 erc20ConfigHash) = getConfigSampleERC20(false);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc20ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain1);
    address sampleErc20Address = holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash);

    assertEq(sampleErc20Address, address(0), "ERC20 contract not deployed on chain1");

    vm.selectFork(chain2);
    sampleErc20Address = holographRegistryChain2.getHolographedHashAddress(erc20ConfigHash);

    vm.selectFork(chain1);
    bytes memory data = abi.encode(erc20Config, signature, deployer);

    address originalMessagingModule = holographOperatorChain1.getMessagingModule();

    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(Constants.getMockLZEndpoint());

    bytes memory payload = getRequestPayload(Constants.getHolographFactoryProxy(), data, false);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      Constants.getHolographFactoryProxy(),
      data,
      payload,
      false,
      150000
    );

    payload = estimatedGas.payload;

    (bool success, ) = address(mockLZEndpointChain1).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain1.crossChainMessage.selector,
        address(holographOperatorChain1),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(sampleErc20Address, erc20ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain1).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain1.executeJob.selector, payload)
    );

    assertEq(
      sampleErc20Address,
      holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash),
      "ERC20 contract not deployed on chain1"
    );
  }

  /**
   * SampleERC721
   */

  /**
   * @notice Helper function to deploy SampleERC721 contract on chain2
   * @dev This helper exists because the same logic will be used for other tests
   */
  function sampleERC721HelperChain2() internal returns (address sampleErc721Address, bytes32 configHash) {
    (DeploymentConfig memory erc721Config, bytes32 erc721ConfigHash) = getConfigSampleERC721(true);
    configHash = erc721ConfigHash;
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc721ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain2);
    sampleErc721Address = holographRegistryChain2.getHolographedHashAddress(erc721ConfigHash);

    assertEq(sampleErc721Address, address(0), "ERC721 contract not deployed on chain2");

    vm.selectFork(chain1);
    sampleErc721Address = holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash);

    vm.selectFork(chain2);
    bytes memory data = abi.encode(erc721Config, signature, deployer);

    address originalMessagingModule = holographOperatorChain2.getMessagingModule();

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(Constants.getMockLZEndpoint());

    bytes memory payload = getRequestPayload(Constants.getHolographFactoryProxy(), data, true);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      Constants.getHolographFactoryProxy(),
      data,
      payload,
      true,
      150000
    );

    payload = estimatedGas.payload;

    (bool success, ) = address(mockLZEndpointChain2).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain2.crossChainMessage.selector,
        address(holographOperatorChain2),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(sampleErc721Address, erc721ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, payload)
    );
  }

  /**
   * @notice deploy chain1 equivalent on chain2
   * @dev deploy the SampleERC721 equivalent on chain2 and check if it's deployed
   */
  function testSampleERC721Chain2() public {
    (address sampleErc721Address, bytes32 erc721ConfigHash) = sampleERC721HelperChain2();

    vm.selectFork(chain2);
    assertEq(
      sampleErc721Address,
      holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash),
      "ERC721 contract not deployed on chain2"
    );
  }

  /**
   * @notice Helper function to deploy SampleERC721 contract on chain1
   * @dev This helper exists because the same logic will be used for other tests
   */
  function sampleERC721HelperChain1() internal returns (address sampleErc721Address, bytes32 configHash) {
    (DeploymentConfig memory erc721Config, bytes32 erc721ConfigHash) = getConfigSampleERC721(false);
    configHash = erc721ConfigHash;
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc721ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain1);
    sampleErc721Address = holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash);

    assertEq(sampleErc721Address, address(0), "ERC721 contract not deployed on chain1");

    vm.selectFork(chain2);
    sampleErc721Address = holographRegistryChain2.getHolographedHashAddress(erc721ConfigHash);

    vm.selectFork(chain1);
    bytes memory data = abi.encode(erc721Config, signature, deployer);

    address originalMessagingModule = holographOperatorChain1.getMessagingModule();

    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(Constants.getMockLZEndpoint());

    bytes memory payload = getRequestPayload(Constants.getHolographFactoryProxy(), data, false);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      Constants.getHolographFactoryProxy(),
      data,
      payload,
      false,
      150000
    );

    payload = estimatedGas.payload;

    (bool success, ) = address(mockLZEndpointChain1).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain1.crossChainMessage.selector,
        address(holographOperatorChain1),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(sampleErc721Address, erc721ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain1).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain1.executeJob.selector, payload)
    );
  }

  /**
   * @notice deploy chain2 equivalent on chain1
   * @dev deploy the SampleERC721 equivalent on chain1 and check if it's deployed
   */
  function testSampleERC721Chain1() public {
    (address sampleErc721Address, bytes32 erc721ConfigHash) = sampleERC721HelperChain1();

    vm.selectFork(chain1);
    assertEq(
      sampleErc721Address,
      holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash),
      "ERC721 contract not deployed on chain1"
    );
  }

  /**
   * CxipERC721
   */

  /**
   * @notice deploy chain1 equivalent on chain2
   * @dev deploy the CxipERC721 equivalent on chain2 and check if it's deployed
   */
  function testCxipERC721Chain2() public {
    (DeploymentConfig memory erc721Config, bytes32 erc721ConfigHash) = getConfigCxipERC721(true);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc721ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain2);
    address cxipErc721Address = holographRegistryChain2.getHolographedHashAddress(erc721ConfigHash);

    assertEq(cxipErc721Address, address(0), "ERC721 contract not deployed on chain2");

    vm.selectFork(chain1);
    cxipErc721Address = holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash);

    vm.selectFork(chain2);
    bytes memory data = abi.encode(erc721Config, signature, deployer);

    address originalMessagingModule = holographOperatorChain2.getMessagingModule();

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(Constants.getMockLZEndpoint());

    bytes memory payload = getRequestPayload(Constants.getHolographFactoryProxy(), data, true);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      Constants.getHolographFactoryProxy(),
      data,
      payload,
      true,
      150000
    );

    payload = estimatedGas.payload;

    (bool success, ) = address(mockLZEndpointChain2).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain2.crossChainMessage.selector,
        address(holographOperatorChain2),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(cxipErc721Address, erc721ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, payload)
    );

    assertEq(
      cxipErc721Address,
      holographRegistryChain2.getHolographedHashAddress(erc721ConfigHash),
      "ERC721 contract not deployed on chain2"
    );
  }

  /**
   * @notice deploy chain2 equivalent on chain1
   * @dev deploy the CxipERC721 equivalent on chain1 and check if it's deployed
   */
  function testCxipERC721Chain1() public {
    (DeploymentConfig memory erc721Config, bytes32 erc721ConfigHash) = getConfigCxipERC721(false);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc721ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain1);
    address cxipErc721Address = holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash);

    assertEq(cxipErc721Address, address(0), "ERC721 contract not deployed on chain1");

    vm.selectFork(chain2);
    cxipErc721Address = holographRegistryChain2.getHolographedHashAddress(erc721ConfigHash);

    vm.selectFork(chain1);
    bytes memory data = abi.encode(erc721Config, signature, deployer);

    address originalMessagingModule = holographOperatorChain1.getMessagingModule();

    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(Constants.getMockLZEndpoint());

    bytes memory payload = getRequestPayload(Constants.getHolographFactoryProxy(), data, false);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      Constants.getHolographFactoryProxy(),
      data,
      payload,
      false,
      150000
    );

    payload = estimatedGas.payload;

    (bool success, ) = address(mockLZEndpointChain1).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain1.crossChainMessage.selector,
        address(holographOperatorChain1),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(cxipErc721Address, erc721ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain1).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain1.executeJob.selector, payload)
    );

    assertEq(
      cxipErc721Address,
      holographRegistryChain1.getHolographedHashAddress(erc721ConfigHash),
      "ERC721 contract not deployed on chain1"
    );
  }

  /**
   * hToken
   */

  /**
   * @notice deploy chain1 equivalent on chain2
   * @dev deploy the hTokenETH equivalent on chain2 and check if it's deployed
   */
  function testHTokenChain2() public {
    (DeploymentConfig memory erc20Config, bytes32 erc20ConfigHash) = getConfigHtokenETH(true);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc20ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain2);
    address hTokenErc20Address = holographRegistryChain2.getHolographedHashAddress(erc20ConfigHash);

    assertEq(hTokenErc20Address, address(0), "ERC20 contract not deployed on chain2");

    vm.selectFork(chain1);
    hTokenErc20Address = holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash);

    vm.selectFork(chain2);
    bytes memory data = abi.encode(erc20Config, signature, deployer);

    address originalMessagingModule = holographOperatorChain2.getMessagingModule();

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(Constants.getMockLZEndpoint());

    bytes memory payload = getRequestPayload(Constants.getHolographFactoryProxy(), data, true);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      Constants.getHolographFactoryProxy(),
      data,
      payload,
      true,
      150000
    );

    payload = estimatedGas.payload;

    (bool success, ) = address(mockLZEndpointChain2).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain2.crossChainMessage.selector,
        address(holographOperatorChain2),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(hTokenErc20Address, erc20ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, payload)
    );

    assertEq(
      hTokenErc20Address,
      holographRegistryChain2.getHolographedHashAddress(erc20ConfigHash),
      "ERC20 contract not deployed on chain2"
    );
  }

  /**
   * @notice deploy chain2 equivalent on chain1
   * @dev deploy the hTokenETH equivalent on chain1 and check if it's deployed
   */
  function testHTokenChain1() public {
    (DeploymentConfig memory erc20Config, bytes32 erc20ConfigHash) = getConfigHtokenETH(false);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeyDeployer, erc20ConfigHash);
    Verification memory signature = Verification({r: r, s: s, v: v});

    vm.selectFork(chain1);
    address hTokenErc20Address = holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash);

    assertEq(hTokenErc20Address, address(0), "ERC20 contract not deployed on chain1");

    vm.selectFork(chain2);
    hTokenErc20Address = holographRegistryChain2.getHolographedHashAddress(erc20ConfigHash);

    vm.selectFork(chain1);
    bytes memory data = abi.encode(erc20Config, signature, deployer);

    address originalMessagingModule = holographOperatorChain1.getMessagingModule();

    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(Constants.getMockLZEndpoint());

    bytes memory payload = getRequestPayload(Constants.getHolographFactoryProxy(), data, false);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      Constants.getHolographFactoryProxy(),
      data,
      payload,
      false,
      150000
    );

    payload = estimatedGas.payload;

    (bool success, ) = address(mockLZEndpointChain1).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain1.crossChainMessage.selector,
        address(holographOperatorChain1),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, false, false);
    emit BridgeableContractDeployed(hTokenErc20Address, erc20ConfigHash);

    vm.prank(operator);
    (bool success2, ) = address(holographOperatorChain1).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain1.executeJob.selector, payload)
    );

    assertEq(
      hTokenErc20Address,
      holographRegistryChain1.getHolographedHashAddress(erc20ConfigHash),
      "ERC20 contract not deployed on chain1"
    );
  }

  /**
   * SampleERC721
   */

  /**
   * check current state
   */

  /**
   * @notice chain1 should have a total supply of 0 on chain1
   * @dev Validates that sampleERC721Holographer has a total supply of 0 on chain1
   */
  function testChain1ShouldHaveTotalSupplyOf0OnChain1() public {
    vm.selectFork(chain1);
    HolographERC721 sampleErc721Enforcer = HolographERC721(payable(address(sampleErc721HolographerChain1)));
    assertEq(sampleErc721Enforcer.totalSupply(), 0, "Chain1 should have a total supply of 0 on chain1");
  }

  /**
   * @notice chain1 should have a total supply of 0 on chain2
   * @dev Validates that sampleERC721Holographer has a total supply of 0 on chain2
   */
  function testChain1ShouldHaveTotalSupplyOf0OnChain2() public {
    sampleERC721HelperChain2();

    vm.selectFork(chain2);
    HolographERC721 sampleErc721Enforcer = HolographERC721(payable(address(sampleErc721HolographerChain1)));
    assertEq(sampleErc721Enforcer.totalSupply(), 0, "Chain1 should have a total supply of 0 on chain2");
  }

  /**
   * @notice chain2 should have a total supply of 0 on chain2
   * @dev Validates that sampleERC721Holographer has a total supply of 0 on chain2
   */
  function testChain2ShouldHaveTotalSupplyOf0OnChain2() public {
    vm.selectFork(chain2);
    HolographERC721 sampleErc721Enforcer = HolographERC721(payable(address(sampleErc721HolographerChain2)));
    assertEq(sampleErc721Enforcer.totalSupply(), 0, "Chain2 should have a total supply of 0 on chain2");
  }

  /**
   * @notice chain2 should have a total supply of 0 on chain1
   * @dev Validates that sampleERC721Holographer has a total supply of 0 on chain1
   */
  function testChain2ShouldHaveTotalSupplyOf0OnChain1() public {
    sampleERC721HelperChain1();

    vm.selectFork(chain1);
    HolographERC721 sampleErc721Enforcer = HolographERC721(payable(address(sampleErc721HolographerChain2)));
    assertEq(sampleErc721Enforcer.totalSupply(), 0, "Chain2 should have a total supply of 0 on chain1");
  }

  /**
   * validate mint functionality
   */

  /**
   * @notice chain1 should mint token #1 as #1 on chain1
   * @dev Validates that sampleERC721Holographer mints token #1 as #1 on chain1
   */
  function testChain1ShouldMintToken1As1OnChain1() public {
    vm.selectFork(chain1);
    SampleERC721 sampleERC721 = SampleERC721(payable(address(sampleErc721HolographerChain1)));

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), deployer, firstTokenIdChain1);

    uint256 gasBefore = gasleft();
    vm.prank(deployer);
    sampleERC721.mint(deployer, firstTokenIdChain1, "https://holograph.xyz/sample1.json");
    uint256 gasUsed = gasBefore - gasleft();
    assertTrue(gasUsed > 0, "Gas used should be greater than 0");
  }

  /**
   * @notice chain1 should mint token #1 not as #1 on chain2
   * @dev Validates that sampleERC721Holographer mints token #1 not as #1 on chain2
   */
  function testChain1ShouldMintToken1NotAs1OnChain2() public {
    sampleERC721HelperChain2();
    vm.selectFork(chain2);
    SampleERC721 sampleERC721 = SampleERC721(payable(address(sampleErc721HolographerChain1)));

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), deployer, firstTokenIdChain2);

    uint256 gasBefore = gasleft();
    vm.prank(deployer);
    sampleERC721.mint(deployer, firstTokenIdChain1, "https://holograph.xyz/sample1.json");
    uint256 gasUsed = gasBefore - gasleft();
    assertTrue(gasUsed > 0, "Gas used should be greater than 0");
  }

  /**
   * @notice mint tokens #2 and #3 on chain1 and chain2
   * @dev Validates that sampleERC721Holographer mints tokens #2 and #3 on chain1 and chain2
   */
  function testMintTokens2And3OnChain1AndChain2() public {
    sampleERC721HelperChain2();
    vm.selectFork(chain1);
    SampleERC721 sampleERC721Chain1 = SampleERC721(payable(address(sampleErc721HolographerChain1)));

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), deployer, secondTokenIdChain1);

    vm.prank(deployer);
    sampleERC721Chain1.mint(deployer, secondTokenIdChain1, "https://holograph.xyz/sample2.json");

    vm.selectFork(chain2);
    SampleERC721 sampleERC721Chain2 = SampleERC721(payable(address(sampleErc721HolographerChain1)));

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), deployer, secondTokenIdChain2);

    vm.prank(deployer);
    sampleERC721Chain2.mint(deployer, secondTokenIdChain1, "https://holograph.xyz/sample2.json");

    vm.selectFork(chain1);
    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), deployer, thirdTokenIdChain1);

    vm.prank(deployer);
    sampleERC721Chain1.mint(deployer, thirdTokenIdChain1, "https://holograph.xyz/sample3.json");

    vm.selectFork(chain2);
    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), deployer, thirdTokenIdChain2);

    vm.prank(deployer);
    sampleERC721Chain2.mint(deployer, thirdTokenIdChain1, "https://holograph.xyz/sample3.json");
  }

  /**
   * validate bridge functionality
   */

  /**
   * @notice token #1 beaming from chain1 to chain2 should succeed | original test uses #3
   * @dev Validates that token #1 beaming from chain1 to chain2 should succeed
   */
  function testTokenBeamingFromChain1ToChain2ShouldSucceed() public {
    testChain1ShouldMintToken1As1OnChain1();
    sampleERC721HelperChain2();

    vm.selectFork(chain1);
    SampleERC721 sampleErc721 = SampleERC721(payable(address(sampleErc721HolographerChain1)));
    string memory tokenURIBefore = sampleErc721.tokenURI(firstTokenIdChain1);

    bytes memory data = abi.encode(deployer, deployer, firstTokenIdChain1);

    address sampleErc721HolographerChain1Address = address(sampleErc721HolographerChain1);

    vm.selectFork(chain2);
    address originalMessagingModule = holographOperatorChain2.getMessagingModule();

    bytes memory payload = getRequestPayload(sampleErc721HolographerChain1Address, data, true);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      sampleErc721HolographerChain1Address,
      data,
      payload,
      true,
      270000
    );

    payload = estimatedGas.payload;

    vm.selectFork(chain1);
    vm.prank(deployer);
    (bool success, ) = address(holographBridgeChain1).call{value: estimatedGas.fee}(
      abi.encodeWithSelector(
        holographBridgeChain1.bridgeOutRequest.selector,
        holographIdL2,
        sampleErc721HolographerChain1Address,
        estimatedGas.estimatedGas,
        GWEI,
        data
      )
    );

    vm.selectFork(chain2);
    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(Constants.getMockLZEndpoint());

    (bool success2, ) = address(mockLZEndpointChain2).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain2.crossChainMessage.selector,
        address(holographOperatorChain2),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), deployer, firstTokenIdChain1);

    vm.prank(operator);
    (bool success3, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, payload)
    );

    HolographERC721 sampleErc721Enforcer = HolographERC721(payable(address(sampleErc721HolographerChain1)));
    assertEq(
      sampleErc721Enforcer.ownerOf(firstTokenIdChain1),
      deployer,
      "Token #1 should be owned by deployer on chain2"
    );

    // token #2 beaming from chain1 to chain2 should keep TokenURI
    string memory tokenURIAfter = sampleErc721Enforcer.tokenURI(firstTokenIdChain1);
    assertEq(tokenURIBefore, tokenURIAfter, "TokenURI should be the same on chain2");
  }

  /**
   * @notice token #1 beaming from chain2 to chain1 should succeed | original test uses #3
   * @dev Validates that token #1 beaming from chain2 to chain1 should succeed
   */
  function testTokenBeamingFromChain2ToChain1ShouldSucceed() public {
    testTokenBeamingFromChain1ToChain2ShouldSucceed();

    vm.selectFork(chain2);
    SampleERC721 sampleErc721 = SampleERC721(payable(address(sampleErc721HolographerChain1)));
    string memory tokenURIBefore = sampleErc721.tokenURI(firstTokenIdChain1);

    bytes memory data = abi.encode(deployer, deployer, firstTokenIdChain1);

    address sampleErc721HolographerChain1Address = address(sampleErc721HolographerChain1);

    vm.selectFork(chain1);
    address originalMessagingModule = holographOperatorChain1.getMessagingModule();

    bytes memory payload = getRequestPayload(sampleErc721HolographerChain1Address, data, false);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      sampleErc721HolographerChain1Address,
      data,
      payload,
      false,
      270000
    );

    payload = estimatedGas.payload;

    vm.selectFork(chain2);
    vm.prank(deployer);
    (bool success, ) = address(holographBridgeChain2).call{value: estimatedGas.fee}(
      abi.encodeWithSelector(
        holographBridgeChain2.bridgeOutRequest.selector,
        holographIdL1,
        sampleErc721HolographerChain1Address,
        estimatedGas.estimatedGas,
        GWEI,
        data
      )
    );

    vm.selectFork(chain1);
    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(Constants.getMockLZEndpoint());

    (bool success2, ) = address(mockLZEndpointChain1).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain1.crossChainMessage.selector,
        address(holographOperatorChain1),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain1.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), deployer, firstTokenIdChain1);

    vm.prank(operator);
    (bool success3, ) = address(holographOperatorChain1).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain1.executeJob.selector, payload)
    );

    HolographERC721 sampleErc721Enforcer = HolographERC721(payable(address(sampleErc721HolographerChain1)));
    assertEq(
      sampleErc721Enforcer.ownerOf(firstTokenIdChain1),
      deployer,
      "Token #1 should be owned by deployer on chain1"
    );

    // token #2 beaming from chain2 to chain1 should keep TokenURI
    string memory tokenURIAfter = sampleErc721Enforcer.tokenURI(firstTokenIdChain1);
    assertEq(tokenURIBefore, tokenURIAfter, "TokenURI should be the same on chain1");
  }

  /**
   * @notice token #1 beaming from chain1 to chain2 should fail and recover | original test uses #3
   * @dev Validates that token #1 beaming from chain1 to chain2 should fail and recover
   */
  function testTokenBeamingFromChain1ToChain2ShouldFailAndRecover() public {
    // TODO: THIS TEST IS NOT WORKING DUE TO THE REVERT: ERC721: token does not exist
    //       REQUIRES LOOKING INTO THE REASON FOR THE REVERT
    vm.skip(true);
    testTokenBeamingFromChain2ToChain1ShouldSucceed();

    bytes memory data = abi.encode(deployer, deployer, firstTokenIdChain1);

    address sampleErc721HolographerChain1Address = address(sampleErc721HolographerChain1);

    vm.selectFork(chain2);
    address originalMessagingModule = holographOperatorChain2.getMessagingModule();

    bytes memory payload = getRequestPayload(sampleErc721HolographerChain1Address, data, true);

    EstimatedGas memory estimatedGas = getEstimatedGas(
      sampleErc721HolographerChain1Address,
      data,
      payload,
      true,
      270000
    );

    payload = estimatedGas.payload;

    uint256 originalGas = estimatedGas.estimatedGas;
    uint256 badLowGas = originalGas / 10;

    vm.selectFork(chain1);

    vm.recordLogs();
    vm.prank(deployer);
    (bool success, ) = address(holographBridgeChain1).call{value: estimatedGas.fee}(
      abi.encodeWithSelector(
        holographBridgeChain1.bridgeOutRequest.selector,
        holographIdL2,
        sampleErc721HolographerChain1Address,
        badLowGas,
        GWEI,
        data
      )
    );

    Vm.Log[] memory logs = vm.getRecordedLogs();
    for (uint256 i = 0; i < logs.length; i++) {
      if (logs[i].emitter == address(mockLZEndpointChain1)) {
        if (logs[i].topics[0] == keccak256("LzEvent(uint16,bytes,bytes)")) {
          (, , bytes memory decodedPayload) = abi.decode(logs[i].data, (uint16, bytes, bytes));

          payload = decodedPayload;
          break;
        }
      }
    }

    vm.selectFork(chain2);
    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(Constants.getMockLZEndpoint());

    (bool success2, ) = address(mockLZEndpointChain2).call{gas: TESTGASLIMIT}(
      abi.encodeWithSelector(
        mockLZEndpointChain2.crossChainMessage.selector,
        address(holographOperatorChain2),
        getLzMsgGas(payload),
        payload
      )
    );

    vm.prank(deployer);
    holographOperatorChain2.setMessagingModule(originalMessagingModule);

    vm.expectEmit(true, false, false, false);
    emit FailedOperatorJob(keccak256(payload));

    vm.prank(operator);
    (bool success3, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.executeJob.selector, payload)
    );

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), deployer, firstTokenIdChain1);

    (bool success4, ) = address(holographOperatorChain2).call{gas: estimatedGas.estimatedGas}(
      abi.encodeWithSelector(holographOperatorChain2.recoverJob.selector, payload)
    );

    HolographERC721 sampleErc721Enforcer = HolographERC721(payable(address(sampleErc721HolographerChain1)));
    assertEq(
      sampleErc721Enforcer.ownerOf(firstTokenIdChain1),
      deployer,
      "Token #1 should be owned by deployer on chain2"
    );
  }

  /**
   * @notice token #2 beaming from chain1 to chain2 should keep TokenURI
   * @dev this is the same logic as the previous test, but with a different tokenId. So we added the TokenURI check in testTokenBeamingFromChain1ToChain2ShouldSucceed
   */

  /**
   * @notice token #2 beaming from chain2 to chain1 should keep TokenURI
   * @dev this is the same logic as the previous test, but with a different tokenId. So we added the TokenURI check in testTokenBeamingFromChain2ToChain1ShouldSucceed
   */

  /**
   * Get gas calculations
   */

  /**
   * @notice SampleERC721 #1 mint on chain1
   * @dev gas is validated on the test testChain1ShouldMintToken1As1OnChain1
   */

  /**
   * @notice SampleERC721 #1 mint on chain2
   * @dev gas is validated on the test testChain1ShouldMintToken1NotAs1OnChain2
   */

  /**
   * @notice SampleERC721 #1 transfer on chain1
   * @dev Validate gas calculation for transfer on chain1
   */
  function testSampleERC721TransferGasCalculationChain1() public {
    testChain1ShouldMintToken1As1OnChain1();

    vm.selectFork(chain1);
    HolographERC721 sampleErc721Enforcer = HolographERC721(payable(address(sampleErc721HolographerChain1)));

    vm.expectEmit(true, true, true, false);
    emit Transfer(deployer, alice, firstTokenIdChain1);

    uint256 gasBefore = gasleft();
    vm.prank(deployer);
    sampleErc721Enforcer.transferFrom(deployer, alice, 1);
    uint256 gasUsed = gasBefore - gasleft();
    assertTrue(gasUsed > 0, "Gas used should be greater than 0");
  }

  /**
   * @notice SampleERC721 #1 transfer on chain2
   * @dev is the same logic as the previous test
   */

  /**
   * Get hToken balances
   */

  /**
   * @notice chain1 hToken should have more than 0
   * @dev Validates that chain1 hToken should have more than 0
   */
  function testChain1HTokenShouldHaveMoreThan0() public {
    testTokenBeamingFromChain1ToChain2ShouldSucceed();
    vm.selectFork(chain1);
    address hTokenAddress = holographRegistryChain1.getHToken(holographIdL1);
    assertNotEq(hTokenAddress.balance, 0, "chain1 hToken should have more than 0");
  }

  /**
   * @notice chain2 hToken should have more than 0
   * @dev Validates that chain2 hToken should have more than 0
   */
  function testChain2HTokenShouldHaveMoreThan0() public {
    testTokenBeamingFromChain2ToChain1ShouldSucceed();
    vm.selectFork(chain2);
    address hTokenAddress = holographRegistryChain2.getHToken(holographIdL2);
    assertNotEq(hTokenAddress.balance, 0, "chain2 hToken should have more than 0");
  }
}
