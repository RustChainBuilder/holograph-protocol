// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Test, Vm, console} from "forge-std/Test.sol";
import {Constants} from "../utils/Constants.sol";
import {HelperDeploymentConfig} from "../utils/HelperDeploymentConfig.sol";
import {HelperSignEthMessage} from "../utils/HelperSignEthMessage.sol";
import {SampleERC20} from "../../../src/token/SampleERC20.sol";
import {ERC20Mock} from "../../../src/mock/ERC20Mock.sol";
import {Holograph} from "../../../src/Holograph.sol";
import {CxipERC721} from "../../../src/token/CxipERC721.sol";
import {CxipERC721Proxy} from "../../../src/proxy/CxipERC721Proxy.sol";
import {HolographBridge} from "../../../src/HolographBridge.sol";
import {HolographBridgeProxy} from "../../../src/proxy/HolographBridgeProxy.sol";
import {Holographer} from "../../../src/enforcer/Holographer.sol";
import {HolographERC20} from "../../../src/enforcer/HolographERC20.sol";
import {HolographERC721} from "../../../src/enforcer/HolographERC721.sol";
import {HolographFactory} from "../../../src/HolographFactory.sol";
import {HolographFactoryProxy} from "../../../src/proxy/HolographFactoryProxy.sol";
import {HolographGenesis} from "../../../src/HolographGenesis.sol";
import {HolographOperator} from "../../../src/HolographOperator.sol";
import {HolographOperatorProxy} from "../../../src/proxy/HolographOperatorProxy.sol";
import {HolographRegistry} from "../../../src/HolographRegistry.sol";
import {HolographRegistryProxy} from "../../../src/proxy/HolographRegistryProxy.sol";
import {HolographTreasury} from "../../../src/HolographTreasury.sol";
import {HolographTreasuryProxy} from "../../../src/proxy/HolographTreasuryProxy.sol";
import {hToken} from "../../../src/token/hToken.sol";
import {HolographInterfaces} from "../../../src/HolographInterfaces.sol";
import {MockERC721Receiver} from "../../../src/mock/MockERC721Receiver.sol";
import {HolographRoyalties} from "../../../src/enforcer/HolographRoyalties.sol";
import {SampleERC721} from "../../../src/token/SampleERC721.sol";
import {DeploymentConfig} from "../../../src/struct/DeploymentConfig.sol";
import {HolographDropERC721} from "../../../src/drops/token/HolographDropERC721.sol";
import {HolographDropERC721V2} from "../../../src/drops/token/HolographDropERC721V2.sol";
import {Verification} from "../../../src/struct/Verification.sol";

contract CrossChainConfiguration is Test {
  event BridgeableContractDeployed(address indexed contractAddress, bytes32 indexed hash);
  uint256 chain1;
  uint256 chain2;
  string LOCALHOST_RPC_URL = vm.envString("LOCALHOST_RPC_URL");
  string LOCALHOST2_RPC_URL = vm.envString("LOCALHOST2_RPC_URL");
  address deployer = Constants.getDeployer();
  Holograph holograph;
  Holograph holographChain1;
  Holograph holographChain2;
  SampleERC20 sampleERC20Chain1;
  SampleERC20 sampleERC20Chain2;
  ERC20Mock erc20Mock;
  ERC20Mock erc20MockChain1;
  ERC20Mock erc20MockChain2;
  CxipERC721Proxy cxipERC721ProxyChain1;
  CxipERC721Proxy cxipERC721ProxyChain2;
  HolographBridge holographBridge;
  HolographBridge holographBridgeChain1;
  HolographBridge holographBridgeChain2;
  HolographBridge bridgeChain1;
  HolographBridge bridgeChain2;
  HolographBridgeProxy holographBridgeProxy;
  HolographBridgeProxy holographBridgeProxyChain1;
  HolographBridgeProxy holographBridgeProxyChain2;
  Holographer holographerChain1;
  Holographer holographerChain2;
  HolographERC20 holographERC20;
  HolographERC20 holographERC20Chain1;
  HolographERC20 holographERC20Chain2;
  HolographERC721 holographERC721;
  HolographERC721 holographERC721Chain1;
  HolographERC721 holographERC721Chain2;
  HolographFactory holographFactory;
  HolographFactory holographFactoryChain1;
  HolographFactory holographFactoryChain2;
  HolographFactory factoryChain1;
  HolographFactory factoryChain2;
  HolographFactoryProxy holographFactoryProxy;
  HolographFactoryProxy holographFactoryProxyChain1;
  HolographFactoryProxy holographFactoryProxyChain2;
  HolographGenesis holographGenesis;
  HolographGenesis holographGenesisChain1;
  HolographGenesis holographGenesisChain2;
  HolographRegistry holographRegistry;
  HolographRegistry registryChain1;
  HolographRegistry registryChain2;
  HolographRegistryProxy holographRegistryProxy;
  HolographRegistryProxy holographRegistryProxyChain1;
  HolographRegistryProxy holographRegistryProxyChain2;
  hToken htoken;
  hToken hTokenChain1;
  hToken hTokenChain2;
  HolographOperator operatorChain1;
  HolographOperator operatorChain2;
  HolographOperator holographOperator;
  HolographOperator holographOperatorChain1;
  HolographOperator holographOperatorChain2;
  HolographOperatorProxy holographOperatorProxy;
  HolographOperatorProxy holographOperatorProxyChain1;
  HolographOperatorProxy holographOperatorProxyChain2;
  HolographTreasury holographTreasury;
  HolographTreasury holographTreasuryChain1;
  HolographTreasury holographTreasuryChain2;
  HolographTreasuryProxy holographTreasuryProxy;
  HolographTreasuryProxy holographTreasuryProxyChain1;
  HolographTreasuryProxy holographTreasuryProxyChain2;
  HolographInterfaces holographInterfaces;
  HolographInterfaces holographInterfacesChain1;
  HolographInterfaces holographInterfacesChain2;
  MockERC721Receiver mockERC721Receiver;
  MockERC721Receiver mockERC721ReceiverChain1;
  MockERC721Receiver mockERC721ReceiverChain2;
  HolographRoyalties holographRoyalties;
  HolographRoyalties holographRoyaltiesChain1;
  HolographRoyalties holographRoyaltiesChain2;
  SampleERC721 sampleERC721Chain1;
  SampleERC721 sampleERC721Chain2;
  Holographer hTokenHolographerChain1;
  Holographer hTokenHolographerChain2;
  HolographERC20 hTokenEnforcer;
  HolographERC20 hTokenEnforcerChain1;
  HolographERC20 hTokenEnforcerChain2;
  Holographer sampleErc20HolographerChain1;
  Holographer sampleErc20HolographerChain2;
  HolographERC20 sampleErc20Enforcer;
  HolographERC20 sampleErc20EnforcerChain1;
  HolographERC20 sampleErc20EnforcerChain2;
  Holographer sampleErc721HolographerChain1;
  Holographer sampleErc721HolographerChain2;
  HolographERC721 sampleErc721Enforcer;
  HolographERC721 sampleErc721EnforcerChain1;
  HolographERC721 sampleErc721EnforcerChain2;
  Holographer cxipErc721HolographerChain1;
  Holographer cxipErc721HolographerChain2;
  HolographERC721 cxipErc721Enforcer;
  HolographERC721 cxipErc721EnforcerChain1;
  HolographERC721 cxipErc721EnforcerChain2;
  HolographDropERC721 holographDropERC721;
  HolographDropERC721V2 holographDropERC721V2;

  function deployTestHToken(bool isChain1) private returns (DeploymentConfig memory, bytes32, Verification memory) {
    string memory tokenName = string.concat("Holographed TestToken chain ", ((isChain1) ? "one" : "two"));
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getDeployConfigERC20(
      bytes32(0x000000000000000000000000000000000000486f6c6f67726170684552433230), //hToken hash
      (isChain1) ? Constants.getHolographIdL1() : Constants.getHolographIdL2(),
      vm.getCode("hTokenProxy.sol:hTokenProxy"),
      tokenName,
      "hTTC1",
      bytes32(0x0000000000000000000000000000000000000000000000000000000000000000),
      tokenName,
      HelperDeploymentConfig.getInitCodeHtokenETH()
    );
    bytes32 hashHtokenTest = HelperDeploymentConfig.getDeployConfigHash(deployConfig, Constants.getDeployer());

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      Constants.getPKDeployer(),
      HelperSignEthMessage.toEthSignedMessageHash(hashHtokenTest)
    );

    Verification memory signature = Verification({v: v, r: r, s: s});
    if ((isChain1)) vm.selectFork(chain1);
    else vm.selectFork(chain2);
    holographFactory.deployHolographableContract(deployConfig, signature, Constants.getDeployer());

    return (deployConfig, hashHtokenTest, signature);
  }

  function deployDropERC721(bool isChain1) private returns (DeploymentConfig memory, bytes32, Verification memory) {
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getERC721WithConfigDropERC721V2(
      Constants.getHolographIdL1(),
      vm.getCode("SampleERC721.sol:SampleERC721"),
      bytes32(HelperDeploymentConfig.dropEventConfig),
      true
    );
    bytes32 hashDropERC721Test = HelperDeploymentConfig.getDeployConfigHash(deployConfig, Constants.getDeployer());

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      Constants.getPKDeployer(),
      HelperSignEthMessage.toEthSignedMessageHash(hashDropERC721Test)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    if ((isChain1)) vm.selectFork(chain1);
    else vm.selectFork(chain2);

    vm.prank(deployer);
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);

    return (deployConfig, hashDropERC721Test, signature);
  }

  function setUp() public {
    cxipERC721ProxyChain1 = CxipERC721Proxy(payable(Constants.getCxipERC721Proxy()));
    cxipERC721ProxyChain2 = CxipERC721Proxy(payable(Constants.getCxipERC721Proxy_L2()));
    erc20Mock = ERC20Mock(payable(Constants.getERC20Mock()));
    holograph = Holograph(payable(Constants.getHolograph()));
    holographBridge = HolographBridge(payable(Constants.getHolographBridge()));
    holographBridgeProxy = HolographBridgeProxy(payable(Constants.getHolographBridgeProxy()));
    holographERC20 = HolographERC20(payable(Constants.getSampleERC20())); /// VER EL ADDRESS...
    holographERC721 = HolographERC721(payable(Constants.getHolographERC721()));
    holographFactory = HolographFactory(payable(Constants.getHolographFactoryProxy()));
    holographFactoryProxy = HolographFactoryProxy(payable(Constants.getHolographFactoryProxy()));
    holographGenesis = HolographGenesis(payable(Constants.getHolographGenesis()));
    holographOperator = HolographOperator(payable(Constants.getHolographOperator()));
    holographOperatorProxy = HolographOperatorProxy(payable(Constants.getHolographOperatorProxy()));
    holographRegistry = HolographRegistry(payable(Constants.getHolographRegistry()));
    holographRegistryProxy = HolographRegistryProxy(payable(Constants.getHolographRegistryProxy()));
    htoken = hToken(payable(Constants.getHToken()));
    holographTreasury = HolographTreasury(payable(Constants.getHolographTreasury()));
    holographTreasuryProxy = HolographTreasuryProxy(payable(Constants.getHolographTreasuryProxy()));
    holographInterfaces = HolographInterfaces(payable(Constants.getHolographInterfaces()));
    mockERC721Receiver = MockERC721Receiver(payable(Constants.getMockERC721Receiver()));
    holographRoyalties = HolographRoyalties(payable(Constants.getHolographRoyalties()));
    sampleERC20Chain1 = SampleERC20(payable(Constants.getSampleERC20()));
    sampleERC20Chain2 = SampleERC20(payable(Constants.getSampleERC20_L2()));
    sampleERC721Chain1 = SampleERC721(payable(Constants.getSampleERC721()));
    sampleERC721Chain2 = SampleERC721(payable(Constants.getSampleERC721_L2()));
    hTokenEnforcer = HolographERC20(payable(Constants.getHolographERC20()));
    sampleErc20Enforcer = HolographERC20(payable(Constants.getHolographERC20()));
    cxipErc721Enforcer = HolographERC721(payable(Constants.getHolographERC721()));
    holographDropERC721 = HolographDropERC721(payable(Constants.getHolographDropERC721()));
    holographDropERC721V2 = HolographDropERC721V2(payable(Constants.getHolographDropERC721V2()));

    chain1 = vm.createFork(LOCALHOST_RPC_URL);
    chain2 = vm.createFork(LOCALHOST2_RPC_URL);

    vm.selectFork(chain1);
    registryChain1 = HolographRegistry(payable(holograph.getRegistry()));
    vm.selectFork(chain2);
    registryChain2 = HolographRegistry(payable(holograph.getRegistry()));

    vm.selectFork(chain1);
    factoryChain1 = HolographFactory(payable(holograph.getFactory()));
    vm.selectFork(chain2);
    factoryChain2 = HolographFactory(payable(holograph.getFactory()));

    vm.selectFork(chain1);
    operatorChain1 = HolographOperator(payable(holograph.getOperator()));
    vm.selectFork(chain2);
    operatorChain2 = HolographOperator(payable(holograph.getOperator()));

    vm.selectFork(chain1);
    bridgeChain1 = HolographBridge(payable(holograph.getBridge()));
    vm.selectFork(chain2);
    bridgeChain2 = HolographBridge(payable(holograph.getBridge()));
  }

  /* -------------------------------------------------------------------------- */
  /*                          VALIDATE CROSS-CHAIN DATA                         */
  /* -------------------------------------------------------------------------- */

  /**
   * @notice This test checks if the addresses of the `cxipERC721Proxy` contracts deployed in chain1 and chain2 are different.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'CxipERC721'
   */
  function testCxipERC721ProxyAddress() public {
    assertNotEq(address(cxipERC721ProxyChain1), address(cxipERC721ProxyChain2));
  }

  /**
   * @notice This test checks if the addresses of the `erc20Mock` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'ERC20Mock'
   */
  function testErc20MockAddress() public {
    vm.selectFork(chain1);
    erc20MockChain1 = erc20Mock;
    vm.selectFork(chain2);
    erc20MockChain2 = erc20Mock;
    assertEq(address(erc20MockChain1), address(erc20MockChain2));
  }

  /**
   * @notice This test checks if the addresses of the `holograph` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'Holograph'
   */
  function testHolographAddress() public {
    vm.selectFork(chain1);
    holographChain1 = holograph;
    vm.selectFork(chain2);
    holographChain2 = holograph;
    assertEq(address(holographChain1), address(holographChain2));
  }

  /**
   * @notice This test checks if the addresses of the `holographBridge` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographBridge'
   */
  function testHolographBridgeAddress() public {
    vm.selectFork(chain1);
    holographBridgeChain1 = holographBridge;
    vm.selectFork(chain2);
    holographBridgeChain2 = holographBridge;
    assertEq(address(holographBridgeChain1), address(holographBridgeChain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographBridgeProxy` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographBridgeProxy'
   */
  function testHolographBridgeProxyAddress() public {
    vm.selectFork(chain1);
    holographBridgeProxyChain1 = holographBridgeProxy;
    vm.selectFork(chain2);
    holographBridgeProxyChain2 = holographBridgeProxy;
    assertEq(address(holographBridgeProxyChain1), address(holographBridgeProxyChain2));
  }

  // TODO Check whether addresses should be the same
  // /**
  //  * @notice This test checks if the addresses of the `Holographer` contracts deployed in chain1 and chain2 are the same.
  //  * @dev This test is considered as a validation test on the deployment performed.
  //  * Refers to the hardhat test with the description 'Holographer'
  //  */
  function testHolographerAddress() public {
    vm.skip(true);
    vm.selectFork(chain1);
    address holographerAddressChain1 = registryChain1.getHToken(Constants.getHolographIdL1());
    vm.selectFork(chain2);
    address holographerAddressChain2 = registryChain2.getHToken(Constants.getHolographIdL2());
    assertNotEq(address(holographerAddressChain1), address(holographerAddressChain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographERC20` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographERC20'
   */
  function testHolographERC20Address() public {
    vm.selectFork(chain1);
    holographERC20Chain1 = holographERC20;
    vm.selectFork(chain2);
    holographERC20Chain2 = holographERC20;
    assertEq(address(holographERC20Chain1), address(holographERC20Chain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographERC721` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographERC721'
   */
  function testHolographERC721Address() public {
    vm.selectFork(chain1);
    holographERC721Chain1 = holographERC721;
    vm.selectFork(chain2);
    holographERC721Chain2 = holographERC721;
    assertEq(address(holographERC721Chain1), address(holographERC721Chain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographFactory` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographFactory'
   */
  function testHolographFactoryAddress() public {
    vm.selectFork(chain1);
    holographFactoryChain1 = holographFactory;
    vm.selectFork(chain2);
    holographFactoryChain2 = holographFactory;
    assertEq(address(holographFactoryChain1), address(holographFactoryChain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographFactoryProxy` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographFactoryProxy'
   */
  function testHolographFactoryProxyAddress() public {
    vm.selectFork(chain1);
    holographFactoryProxyChain1 = holographFactoryProxy;
    vm.selectFork(chain2);
    holographFactoryProxyChain2 = holographFactoryProxy;
    assertEq(address(holographFactoryProxyChain1), address(holographFactoryProxyChain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographGenesis` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographGenesis'
   */
  function testHolographGenesisAddress() public {
    vm.selectFork(chain1);
    holographGenesisChain1 = holographGenesis;
    vm.selectFork(chain2);
    holographGenesisChain2 = holographGenesis;
    assertEq(address(holographGenesisChain1), address(holographGenesisChain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographOperator` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographOperator'
   */
  function testHolographOperatorAddress() public {
    vm.selectFork(chain1);
    holographOperatorChain1 = holographOperator;
    vm.selectFork(chain2);
    holographOperatorChain2 = holographOperator;
    assertEq(address(holographOperatorChain1), address(holographOperatorChain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographOperatorProxy` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographOperatorProxy'
   */
  function testHolographOperatorProxyAddress() public {
    vm.selectFork(chain1);
    holographOperatorProxyChain1 = holographOperatorProxy;
    vm.selectFork(chain2);
    holographOperatorProxyChain2 = holographOperatorProxy;
    assertEq(address(holographOperatorProxyChain1), address(holographOperatorProxyChain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographRegistry` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographRegistry'
   */
  function testHolographRegistryAddress() public {
    vm.selectFork(chain1);
    HolographRegistry holographRegistryChain1 = holographRegistry;
    vm.selectFork(chain2);
    HolographRegistry holographRegistryChain2 = holographRegistry;
    assertEq(address(holographRegistryChain1), address(holographRegistryChain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographRegistryProxy` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographRegistryProxy'
   */
  function testHolographRegistryProxyAddress() public {
    vm.selectFork(chain1);
    holographRegistryProxyChain1 = holographRegistryProxy;
    vm.selectFork(chain2);
    holographRegistryProxyChain2 = holographRegistryProxy;
    assertEq(address(holographRegistryProxyChain1), address(holographRegistryProxyChain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographTreasury` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographTreasury'
   */
  function testHolographTreasuryAddress() public {
    vm.selectFork(chain1);
    holographTreasuryChain1 = holographTreasury;
    vm.selectFork(chain2);
    holographTreasuryChain2 = holographTreasury;
    assertEq(address(holographTreasuryChain1), address(holographTreasuryChain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographTreasuryProxy` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographTreasuryProxy'
   */
  function testHolographTreasuryProxyAddress() public {
    vm.selectFork(chain1);
    holographTreasuryProxyChain1 = holographTreasuryProxy;
    vm.selectFork(chain2);
    holographTreasuryProxyChain2 = holographTreasuryProxy;
    assertEq(address(holographTreasuryProxyChain1), address(holographTreasuryProxyChain2));
  }

  /**
   * @notice This test checks if the addresses of the `hToken` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'hToken'
   */
  function testHTokenAddress() public {
    vm.selectFork(chain1);
    hTokenChain1 = htoken;
    vm.selectFork(chain2);
    hTokenChain2 = htoken;
    assertEq(address(hTokenChain1), address(hTokenChain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographInterfaces` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographInterfaces'
   */
  function testHolographInterfacesAddress() public {
    vm.selectFork(chain1);
    holographInterfacesChain1 = holographInterfaces;
    vm.selectFork(chain2);
    holographInterfacesChain2 = holographInterfaces;
    assertEq(address(holographInterfacesChain1), address(holographInterfacesChain2));
  }

  /**
   * @notice This test checks if the addresses of the `MockERC721Receiver` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'MockERC721Receiver'
   */
  function testMockERC721ReceiverAddress() public {
    vm.selectFork(chain1);
    mockERC721ReceiverChain1 = mockERC721Receiver;
    vm.selectFork(chain2);
    mockERC721ReceiverChain2 = mockERC721Receiver;
    assertEq(address(mockERC721ReceiverChain1), address(mockERC721ReceiverChain2));
  }

  /**
   * @notice This test checks if the addresses of the `HolographRoyalties` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographRoyalties'
   */
  function testHolographRoyaltiesAddress() public {
    vm.selectFork(chain1);
    holographRoyaltiesChain1 = holographRoyalties;
    vm.selectFork(chain2);
    holographRoyaltiesChain2 = holographRoyalties;
    assertEq(address(holographRoyaltiesChain1), address(holographRoyaltiesChain2));
  }

  /**
   * @notice This test checks if the addresses of the `SampleERC20` contracts deployed in chain1 and chain2 are different.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'SampleERC20'
   */
  function testSampleERC20Address() public {
    assertNotEq(address(sampleERC20Chain1), address(sampleERC20Chain2));
  }

  /**
   * @notice This test checks if the addresses of the `SampleERC721` contracts deployed in chain1 and chain2 are different.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'SampleERC721'
   */
  function testSampleERC721Address() public {
    assertNotEq(address(sampleERC721Chain1), address(sampleERC721Chain2));
  }

  /**
   * @notice This test checks if the addresses of the `Registry` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographRegistry'
   */
  function testRegistryAddress() public {
    assertEq(address(registryChain1), address(registryChain2));
  }

  /**
   * @notice This test checks if the addresses of the `Factory` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographFactory'
   */
  function testFactoryAddress() public {
    assertEq(address(factoryChain1), address(factoryChain2));
  }

  /**
   * @notice This test checks if the addresses of the `Bridge` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'HolographBridge'
   */
  function testBridgeAddress() public {
    assertEq(address(bridgeChain1), address(bridgeChain2));
  }

  // /**
  //  * @notice This test checks if the addresses of the `hTokenHolographer` contracts deployed in chain1 and chain2 are the same.
  //  * @dev This test is considered as a validation test on the deployment performed.
  //  * Refers to the hardhat test with the description 'hTokenHolographer'
  //  */
  function testHolographHToken() public {
    // deploy on chain 1
    (, bytes32 hashHtokenTestChain1, ) = deployTestHToken(true);
    vm.selectFork(chain1);
    address hTokenAddressChain1 = registryChain1.getHolographedHashAddress(hashHtokenTestChain1);
    // deploy on chain 2
    (, bytes32 hashHtokenTestChain2, ) = deployTestHToken(false);
    vm.selectFork(chain2);
    address hTokenAddressChain2 = registryChain2.getHolographedHashAddress(hashHtokenTestChain2);
    assertNotEq(address(hTokenAddressChain1), address(hTokenAddressChain2));
  }

  /**
   * @notice This test checks if the addresses of the `'hToken HolographERC20 Enforcer` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'hToken HolographERC20 Enforcer'
   */
  function testHTokenHolographErc20Address() public {
    vm.selectFork(chain1);
    hTokenEnforcerChain1 = hTokenEnforcer;
    vm.selectFork(chain2);
    hTokenEnforcerChain2 = hTokenEnforcer;
    assertEq(address(hTokenEnforcerChain1), address(hTokenEnforcerChain2));
  }

  // /**
  //  * @notice This test checks if the addresses of the `sampleErc20 Holographer` contracts deployed in chain1 and chain2 are the same.
  //  * @dev This test is considered as a validation test on the deployment performed.
  //  * Refers to the hardhat test with the description 'SampleERC20 Holographer'
  //  */
  function testSampleERC20Holographer() public {
    vm.selectFork(chain1);
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getERC20(
      Constants.getHolographIdL1(),
      vm.getCode("SampleERC20.sol:SampleERC20"),
      true
    );
    bytes32 hashSampleERC20TestChain1 = HelperDeploymentConfig.getDeployConfigHash(
      deployConfig,
      Constants.getDeployer()
    );
    address sampleERC20AddressChain1 = registryChain1.getHolographedHashAddress(hashSampleERC20TestChain1);

    vm.selectFork(chain2);
    DeploymentConfig memory deployConfig_L2 = HelperDeploymentConfig.getERC20(
      Constants.getHolographIdL2(),
      vm.getCode("SampleERC20.sol:SampleERC20"),
      false
    );
    bytes32 hashSampleERC20TestChain2 = HelperDeploymentConfig.getDeployConfigHash(
      deployConfig_L2,
      Constants.getDeployer()
    );
    address sampleERC20AddressChain2 = registryChain2.getHolographedHashAddress(hashSampleERC20TestChain2);

    assertNotEq(address(sampleERC20AddressChain1), address(sampleERC20AddressChain2));
  }

  /**
   * @notice This test checks if the addresses of the `'SampleERC20 HolographERC20 Enforcer` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'SampleERC20 HolographERC20 Enforcer'
   */
  function testSampleErc20EnforcerAddress() public {
    vm.selectFork(chain1);
    sampleErc20EnforcerChain1 = sampleErc20Enforcer;
    vm.selectFork(chain2);
    sampleErc20EnforcerChain2 = sampleErc20Enforcer;
    assertEq(address(sampleErc20EnforcerChain1), address(sampleErc20EnforcerChain2));
  }

  // /**
  //  * @notice This test checks if the addresses of the `SampleERC721 Holographer` contracts deployed in chain1 and chain2 are the same.
  //  * @dev This test is considered as a validation test on the deployment performed.
  //  * Refers to the hardhat test with the description 'SampleERC721 Holographer'
  //  */
  function testSampleERC721HolographerAddress() public {
    vm.selectFork(chain1);
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getERC721(
      Constants.getHolographIdL1(),
      vm.getCode("SampleERC721.sol:SampleERC721"),
      bytes32(0x0000000000000000000000000000000000000000000000000000000000000086),
      true
    );
    bytes32 hashSampleERC721TestChain1 = HelperDeploymentConfig.getDeployConfigHash(
      deployConfig,
      Constants.getDeployer()
    );
    address sampleERC721AddressChain1 = registryChain1.getHolographedHashAddress(hashSampleERC721TestChain1);

    vm.selectFork(chain2);
    DeploymentConfig memory deployConfig_L2 = HelperDeploymentConfig.getERC721(
      Constants.getHolographIdL2(),
      vm.getCode("SampleERC721.sol:SampleERC721"),
      bytes32(0x0000000000000000000000000000000000000000000000000000000000000086),
      true
    );
    bytes32 hashSampleERC721TestChain2 = HelperDeploymentConfig.getDeployConfigHash(
      deployConfig_L2,
      Constants.getDeployer()
    );
    address sampleERC721AddressChain2 = registryChain2.getHolographedHashAddress(hashSampleERC721TestChain2);

    assertNotEq(address(sampleERC721AddressChain1), address(sampleERC721AddressChain2));
  }

  /**
   * @notice This test checks if the addresses of the `'SampleERC721 HolographERC721 Enforcer` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'SampleERC721 HolographERC721 Enforcer'
   */
  function testSampleErc721EnforcerAddress() public {
    vm.selectFork(chain1);
    sampleErc721EnforcerChain1 = sampleErc721Enforcer;
    vm.selectFork(chain2);
    sampleErc721EnforcerChain2 = sampleErc721Enforcer;
    assertEq(address(sampleErc721EnforcerChain1), address(sampleErc721EnforcerChain2));
  }

  // TODO Check whether to use the bytecode of the CxipERC721 or CxipERC721Proxy contract and whether the addresses should be the same.
  // /**
  //  * @notice This test checks if the addresses of the `SampleERC721 Holographer` contracts deployed in chain1 and chain2 are the same.
  //  * @dev This test is considered as a validation test on the deployment performed.
  //  * Refers to the hardhat test with the description 'CxipERC721 Holographer'
  //  */
  function testCxipErc721HolographerAddress() public {
    vm.skip(true);
    vm.selectFork(chain1);
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getCxipERC721(
      Constants.getHolographIdL1(),
      vm.getCode("CxipERC721Proxy.sol:CxipERC721Proxy"),
      bytes32(0x0000000000000000000000000000000000000000000000000000000000000086),
      true
    );
    bytes32 hashSampleCxipERC721TestChain1 = HelperDeploymentConfig.getDeployConfigHash(
      deployConfig,
      Constants.getDeployer()
    );
    address cxipERC721AddressChain1 = registryChain1.getHolographedHashAddress(hashSampleCxipERC721TestChain1);

    vm.selectFork(chain2);
    DeploymentConfig memory deployConfig_L2 = HelperDeploymentConfig.getCxipERC721(
      Constants.getHolographIdL2(),
      vm.getCode("CxipERC721Proxy.sol:CxipERC721Proxy"),
      bytes32(0x0000000000000000000000000000000000000000000000000000000000000086),
      false
    );
    bytes32 hashSampleCxipERC721TestChain2 = HelperDeploymentConfig.getDeployConfigHash(
      deployConfig_L2,
      Constants.getDeployer()
    );
    address cxipERC721AddressChain2 = registryChain2.getHolographedHashAddress(hashSampleCxipERC721TestChain2);

    assertNotEq(address(cxipERC721AddressChain1), address(cxipERC721AddressChain2));
  }

  /**
   * @notice This test checks if the addresses of the `'SampleERC721 HolographERC721 Enforcer` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   * Refers to the hardhat test with the description 'SampleERC721 HolographERC721 Enforcer'
   */
  function testCxipErc721EnforcerAddress() public {
    vm.selectFork(chain1);
    cxipErc721EnforcerChain1 = cxipErc721Enforcer;
    vm.selectFork(chain2);
    cxipErc721EnforcerChain2 = cxipErc721Enforcer;
    assertEq(address(cxipErc721EnforcerChain1), address(cxipErc721EnforcerChain2));
  }

  /**
   * @notice This test checks if the addresses of the `'holographDropERC721` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   */
  function testHolographDropERC721Address() public {
    vm.selectFork(chain1);
    HolographDropERC721 holographDropERC721Chain1 = holographDropERC721;
    vm.selectFork(chain2);
    HolographDropERC721 holographDropERC721Chain2 = holographDropERC721;
    assertEq(address(holographDropERC721Chain1), address(holographDropERC721Chain2));
  }

  /**
   * @notice This test checks if the addresses of the `'holographDropERC721V2` contracts deployed in chain1 and chain2 are the same.
   * @dev This test is considered as a validation test on the deployment performed.
   */
  function testHolographDropERC721V2Address() public {
    vm.selectFork(chain1);
    HolographDropERC721V2 holographDropERC721V2Chain1 = holographDropERC721V2;
    vm.selectFork(chain2);
    HolographDropERC721V2 holographDropERC721V2Chain2 = holographDropERC721V2;
    assertEq(address(holographDropERC721V2Chain1), address(holographDropERC721V2Chain2));
  }

  /* -------------------------------------------------------------------------- */
  /*                        DEPLOY CROSS-CHAIN CONTRACTS                        */
  /* -------------------------------------------------------------------------- */
  function testDeployHTokenChain1EquivalentOnChain2() public {
    (DeploymentConfig memory deployConfig, bytes32 hashHtokenTest, Verification memory signature) = deployTestHToken(
      true
    );
    // Verify that the contract does not exist on chain2
    vm.selectFork(chain2);
    assertEq(address(registryChain2.getHolographedHashAddress(hashHtokenTest)), Constants.zeroAddress);
    vm.selectFork(chain1);
    address hTokenTestAddress = registryChain1.getHolographedHashAddress(hashHtokenTest);

    vm.selectFork(chain2);
    // Verify that the new contract has the same address thath chain1 and the hash signed
    vm.expectEmit(true, true, false, true);
    emit BridgeableContractDeployed(hTokenTestAddress, hashHtokenTest);
    vm.prank(deployer);
    // Deploy the holographable contract on chain2
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  function testDeployHTokenChain2EquivalentOnChain1() public {
    (DeploymentConfig memory deployConfig, bytes32 hashHtokenTest, Verification memory signature) = deployTestHToken(
      false
    );

    // Verify that the contract does not exist on chain1
    vm.selectFork(chain1);
    assertEq(address(registryChain1.getHolographedHashAddress(hashHtokenTest)), Constants.zeroAddress);
    vm.selectFork(chain2);
    address hTokenTestAddress = registryChain2.getHolographedHashAddress(hashHtokenTest);

    vm.selectFork(chain1);
    // Verify that the new contract has the same address thath chain2 and the hash signed
    vm.expectEmit(true, true, false, true);
    emit BridgeableContractDeployed(hTokenTestAddress, hashHtokenTest);
    vm.prank(deployer);
    // Deploy the holographable contract on chain2
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  /* -------------------------------------------------------------------------- */
  /*                             SECTION SampleERC20                            */
  /* -------------------------------------------------------------------------- */

  function testDeploySampleErc20Chain1EquivalentOnChain2() public {
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getERC20(
      Constants.getHolographIdL1(),
      vm.getCode("SampleERC20.sol:SampleERC20"),
      true
    );

    bytes32 hashTokenTest = HelperDeploymentConfig.getDeployConfigHash(deployConfig, Constants.getDeployer());
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      Constants.getPKDeployer(),
      HelperSignEthMessage.toEthSignedMessageHash(hashTokenTest)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    // Verify that the contract does not exist on chain2
    vm.selectFork(chain2);
    assertEq(address(registryChain2.getHolographedHashAddress(hashTokenTest)), Constants.zeroAddress);
    vm.selectFork(chain1);
    address hTokenTestAddress = registryChain1.getHolographedHashAddress(hashTokenTest);

    vm.selectFork(chain2);
    // Verify that the new contract has the same address thath chain1 and the hash signed
    vm.expectEmit(true, true, false, true);
    emit BridgeableContractDeployed(hTokenTestAddress, hashTokenTest);
    vm.prank(deployer);
    // Deploy the holographable contract on chain2
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  function testDeploySampleErc20Chain2EquivalentOnChain1() public {
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getERC20(
      Constants.getHolographIdL2(),
      vm.getCode("SampleERC20.sol:SampleERC20"),
      false
    );

    bytes32 hashTokenTest = HelperDeploymentConfig.getDeployConfigHash(deployConfig, Constants.getDeployer());
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      Constants.getPKDeployer(),
      HelperSignEthMessage.toEthSignedMessageHash(hashTokenTest)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    // Verify that the contract does not exist on chain1
    vm.selectFork(chain1);
    assertEq(address(registryChain1.getHolographedHashAddress(hashTokenTest)), Constants.zeroAddress);
    vm.selectFork(chain2);
    address hTokenTestAddress = registryChain2.getHolographedHashAddress(hashTokenTest);

    vm.selectFork(chain1);
    // Verify that the new contract has the same address thath chain2 and the hash signed
    vm.expectEmit(true, true, false, true);
    emit BridgeableContractDeployed(hTokenTestAddress, hashTokenTest);
    vm.prank(deployer);
    // Deploy the holographable contract on chain1
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  /* -------------------------------------------------------------------------- */
  /*                            SECTION SampleERC721                            */
  /* -------------------------------------------------------------------------- */

  function testDeploySampleErc721Chain1EquivalentOnChain2() public {
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getERC721(
      Constants.getHolographIdL1(),
      vm.getCode("SampleERC721.sol:SampleERC721"),
      bytes32(0x0000000000000000000000000000000000000000000000000000000000000086),
      true
    );

    bytes32 hashTokenTest = HelperDeploymentConfig.getDeployConfigHash(deployConfig, Constants.getDeployer());
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      Constants.getPKDeployer(),
      HelperSignEthMessage.toEthSignedMessageHash(hashTokenTest)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    // Verify that the contract does not exist on chain1
    vm.selectFork(chain2);
    assertEq(address(registryChain2.getHolographedHashAddress(hashTokenTest)), Constants.zeroAddress);
    vm.selectFork(chain1);
    address hTokenTestAddress = registryChain1.getHolographedHashAddress(hashTokenTest);

    vm.selectFork(chain2);
    // Verify that the new contract has the same address thath chain2 and the hash signed
    vm.expectEmit(true, true, false, true);
    emit BridgeableContractDeployed(hTokenTestAddress, hashTokenTest);
    vm.prank(deployer);
    // Deploy the holographable contract on chain1
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  function testDeploySampleErc721Chain2EquivalentOnChain1() public {
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getERC721(
      Constants.getHolographIdL2(),
      vm.getCode("SampleERC721.sol:SampleERC721"),
      bytes32(0x0000000000000000000000000000000000000000000000000000000000000086),
      false
    );

    bytes32 hashTokenTest = HelperDeploymentConfig.getDeployConfigHash(deployConfig, Constants.getDeployer());
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      Constants.getPKDeployer(),
      HelperSignEthMessage.toEthSignedMessageHash(hashTokenTest)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    // Verify that the contract does not exist on chain2
    vm.selectFork(chain1);
    assertEq(address(registryChain1.getHolographedHashAddress(hashTokenTest)), Constants.zeroAddress);
    vm.selectFork(chain2);
    address hTokenTestAddress = registryChain2.getHolographedHashAddress(hashTokenTest);

    vm.selectFork(chain1);
    // Verify that the new contract has the same address thath chain1 and the hash signed
    vm.expectEmit(true, true, false, true);
    emit BridgeableContractDeployed(hTokenTestAddress, hashTokenTest);
    vm.prank(deployer);
    // Deploy the holographable contract on chain2
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  /* -------------------------------------------------------------------------- */
  /*                             SECTION CxipERC721                             */
  /* -------------------------------------------------------------------------- */

  function testDeployCxipERC721Chain1EquivalentOnChain2() public {
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getCxipERC721(
      Constants.getHolographIdL1(),
      vm.getCode("CxipERC721Proxy.sol:CxipERC721Proxy"),
      bytes32(0x0000000000000000000000000000000000000000000000000000000000000086),
      true
    );

    bytes32 hashTokenTest = HelperDeploymentConfig.getDeployConfigHash(deployConfig, Constants.getDeployer());
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      Constants.getPKDeployer(),
      HelperSignEthMessage.toEthSignedMessageHash(hashTokenTest)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    // Verify that the contract does not exist on chain1
    vm.selectFork(chain2);
    assertEq(address(registryChain2.getHolographedHashAddress(hashTokenTest)), Constants.zeroAddress);
    vm.selectFork(chain1);
    address hTokenTestAddress = registryChain1.getHolographedHashAddress(hashTokenTest);

    vm.selectFork(chain2);
    // Verify that the new contract has the same address thath chain2 and the hash signed
    vm.expectEmit(true, true, false, true);
    emit BridgeableContractDeployed(hTokenTestAddress, hashTokenTest);
    vm.prank(deployer);
    // Deploy the holographable contract on chain1
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  function testDeployCxipERC721Chain2EquivalentOnChain1() public {
    DeploymentConfig memory deployConfig = HelperDeploymentConfig.getCxipERC721(
      Constants.getHolographIdL2(),
      vm.getCode("CxipERC721Proxy.sol:CxipERC721Proxy"),
      bytes32(0x0000000000000000000000000000000000000000000000000000000000000086),
      false
    );

    bytes32 hashTokenTest = HelperDeploymentConfig.getDeployConfigHash(deployConfig, Constants.getDeployer());
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      Constants.getPKDeployer(),
      HelperSignEthMessage.toEthSignedMessageHash(hashTokenTest)
    );
    Verification memory signature = Verification({v: v, r: r, s: s});

    // Verify that the contract does not exist on chain2
    vm.selectFork(chain1);
    assertEq(address(registryChain1.getHolographedHashAddress(hashTokenTest)), Constants.zeroAddress);
    vm.selectFork(chain2);
    address hTokenTestAddress = registryChain1.getHolographedHashAddress(hashTokenTest);

    vm.selectFork(chain1);
    // Verify that the new contract has the same address thath chain1 and the hash signed
    vm.expectEmit(true, true, false, true);
    emit BridgeableContractDeployed(hTokenTestAddress, hashTokenTest);
    vm.prank(deployer);
    // Deploy the holographable contract on chain1
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  /* -------------------------------------------------------------------------- */
  /*                            SECTION DropERC721V2                            */
  /* -------------------------------------------------------------------------- */

  function testDeployHolographDropERC721V2Chain1EquivalentOnChain2() public {
    (
      DeploymentConfig memory deployConfig,
      bytes32 hashDropERC721Test,
      Verification memory signature
    ) = deployDropERC721(true);

    // Verify that the contract does not exist on chain1
    vm.selectFork(chain2);
    assertEq(address(registryChain2.getHolographedHashAddress(hashDropERC721Test)), Constants.zeroAddress);
    vm.selectFork(chain1);
    address hTokenTestAddress = registryChain1.getHolographedHashAddress(hashDropERC721Test);

    vm.selectFork(chain2);
    // Verify that the new contract has the same address thath chain2 and the hash signed
    vm.expectEmit(true, true, false, true);
    emit BridgeableContractDeployed(hTokenTestAddress, hashDropERC721Test);
    vm.prank(deployer);
    // Deploy the holographable contract on chain1
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  function testDeployHolographDropERC721V2Chain2EquivalentOnChain1() public {
    (
      DeploymentConfig memory deployConfig,
      bytes32 hashDropERC721Test,
      Verification memory signature
    ) = deployDropERC721(false);

    // Verify that the contract does not exist on chain1
    vm.selectFork(chain1);
    assertEq(address(registryChain1.getHolographedHashAddress(hashDropERC721Test)), Constants.zeroAddress);
    vm.selectFork(chain2);
    address hTokenTestAddress = registryChain2.getHolographedHashAddress(hashDropERC721Test);

    vm.selectFork(chain1);
    // Verify that the new contract has the same address thath chain1 and the hash signed
    vm.expectEmit(true, true, false, true);
    emit BridgeableContractDeployed(hTokenTestAddress, hashDropERC721Test);
    vm.prank(deployer);
    // Deploy the holographable contract on chain2
    holographFactory.deployHolographableContract(deployConfig, signature, deployer);
  }

  /* -------------------------------------------------------------------------- */
  /*                            VERIFY CHAIN CONFIGS                            */
  /* -------------------------------------------------------------------------- */

  /**
@notice Tests that the Messaging Module address on Chain1 is not zero
@dev This function selects the local host fork and asserts that the Messaging Module address retrieved from 
operatorChain1 is not equal to the zero address
*/
  function testMessagingModuleNotZeroChain1() public {
    vm.selectFork(chain1);
    assertNotEq(operatorChain1.getMessagingModule(), Constants.zeroAddress);
  }

  /**
@notice Tests that the Messaging Module address on Chain2 is not zero
@dev This function selects the local host fork and asserts that the Messaging Module address retrieved from 
operatorChain2 is not equal to the zero address
*/
  function testMessagingModuleNotZeroChain2() public {
    vm.selectFork(chain2);
    assertNotEq(operatorChain2.getMessagingModule(), Constants.zeroAddress);
  }

  /**
@notice Tests that the Messaging Module addresses on Chain1 and Chain2 are the same
@dev This function asserts that the Messaging Module address retrieved from operatorChain1 is equal to the 
Messaging Module address retrieved from operatorChain2
*/
  function testMessagingModuleSameAddress() public {
    assertEq(operatorChain1.getMessagingModule(), operatorChain2.getMessagingModule());
  }

  /**
@notice Tests the Chain ID on Chain2
@dev This function selects the local host fork and asserts that the Chain ID retrieved from the Holograph contract is equal to 4294967294
*/
  function testChainId1() public {
    vm.selectFork(chain1);
    assertEq(holograph.getHolographChainId(), 4294967294);
  }

  /**
@notice Tests the Chain ID on Chain2
@dev This function selects the local host fork and asserts that the Chain ID retrieved from the Holograph contract is equal to 4294967294
*/
  function testChainId2() public {
    vm.selectFork(chain1);
    assertEq(holograph.getHolographChainId(), 4294967294);
  }
}
