// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
import {Constants} from "./Constants.sol";
import {RandomAddress} from "./Utils.sol";
import {DummyMetadataRenderer} from "./DummyMetadataRenderer.sol";

import {DeploymentConfig} from "../../../src/struct/DeploymentConfig.sol";
import {Test, Vm, console} from "forge-std/Test.sol";

import {DropsInitializerV2} from "../../../src/drops/struct/DropsInitializerV2.sol";
import {SalesConfiguration} from "../../../src/drops/struct/SalesConfiguration.sol";

library HelperDeploymentConfig {
  uint256 constant dropEventConfig = 0x0000000000000000000000000000000000000000000000000000000000040000;

  function getInitCodeHtokenETH() public pure returns (bytes memory) {
    return
      abi.encode(
        Constants.hTokenHash,
        Constants.getHolographRegistryProxy(), //registry address
        abi.encode(Constants.getDeployer(), uint16(0))
      );
  }

  function getInitCodeSampleErc721() public pure returns (bytes memory) {
    return abi.encode(Constants.getDeployer());
  }

  function getInitCodeSampleErc20() public pure returns (bytes memory) {
    return abi.encode(Constants.getDeployer(), uint16(0));
  }

  function getInitCodeCxipERC721() public pure returns (bytes memory) {
    bytes32 CxipERC721Hex = Constants.cxipERC721Hex;
    return abi.encode(CxipERC721Hex, Constants.getHolographRegistryProxy(), getInitCodeSampleErc721());
  }

  function getDeployConfigERC20(
    bytes32 contractType,
    uint32 chainType,
    bytes memory contractByteCode,
    string memory tokenName,
    string memory tokenSymbol,
    bytes32 eventConfig,
    string memory domainSeparator,
    bytes memory initCode
  ) public pure returns (DeploymentConfig memory deployConfig) {
    deployConfig.contractType = contractType; //hToken
    deployConfig.chainType = chainType; //holograph id
    deployConfig.salt = Constants.saltHex;
    deployConfig.byteCode = contractByteCode;
    deployConfig.initCode = abi.encode(
      tokenName, //token name
      tokenSymbol, //tokenSymbol
      uint8(18), //decimals
      eventConfig, //eventConfig
      domainSeparator, //domainSeparator
      "1", //domainVersion
      false, //skipInit,
      initCode
    );
    return deployConfig;
  }

  function getDeployConfigERC721(
    bytes32 contractType,
    uint32 chainType,
    bytes memory contractByteCode,
    string memory tokenName,
    string memory tokenSymbol,
    bytes32 eventConfig,
    uint16 royaltyBps,
    bytes memory initCode
  ) public pure returns (DeploymentConfig memory deployConfig) {
    deployConfig.contractType = contractType;
    deployConfig.chainType = chainType; //holograph id
    deployConfig.salt = Constants.saltHex;
    deployConfig.byteCode = contractByteCode;
    deployConfig.initCode = abi.encode(
      tokenName, //token name
      tokenSymbol, //tokenSymbol
      royaltyBps, //royaltyBps
      eventConfig, //eventConfig
      false, //skipInit,
      initCode
    );
    return deployConfig;
  }

  function getDeployConfigHash(DeploymentConfig memory deployConfig, address deployer) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          deployConfig.contractType,
          deployConfig.chainType,
          deployConfig.salt,
          keccak256(deployConfig.byteCode),
          keccak256(deployConfig.initCode),
          deployer
        )
      );
  }

  /*
   * @note This contract is used to get the DeploymentConfig for hToken ETH
   * @dev This contract provides helper functions  to get the DeploymentConfig by chainType (getHolographIdL1 or getHolographIdL2) for hToken ETH
   */
  function getHtokenEth(
    uint32 chainType,
    bytes memory contractByteCode,
    bytes32 eventConfig,
    bool isL1
  ) public pure returns (DeploymentConfig memory deployConfig) {
    return
      getDeployConfigERC20(
        Constants.erc20Hash,
        chainType,
        contractByteCode,
        "Holographed ETH",
        "hETH",
        Constants.EMPTY_BYTES32,
        "Holographed ETH",
        getInitCodeHtokenETH()
      );
  }

  function getERC20(
    uint32 chainType,
    bytes memory contractByteCode,
    bool isL1
  ) public pure returns (DeploymentConfig memory deployConfig) {
    return
      getDeployConfigERC20(
        Constants.erc20Hash,
        chainType,
        contractByteCode,
        isL1 ? "Sample ERC20 Token (localhost)" : "Sample ERC20 Token (localhost2)",
        "SMPL",
        0x0000000000000000000000000000000000000000000000000000000000000006,
        "Sample ERC20 Token",
        getInitCodeSampleErc20()
      );
  }

  function getCxipERC721(
    uint32 chainType,
    bytes memory contractByteCode,
    bytes32 eventConfig,
    bool isL1
  ) public pure returns (DeploymentConfig memory deployConfig) {
    return
      getDeployConfigERC721(
        Constants.holographERC721Hash,
        chainType,
        contractByteCode,
        isL1 ? "CXIP ERC721 Collection (localhost)" : "CXIP ERC721 Collection (localhost2)",
        "CXIP",
        eventConfig, //eventConfig
        1000, //royalty
        getInitCodeCxipERC721()
      );
  }

  function getERC721(
    uint32 chainType,
    bytes memory contractByteCode,
    bytes32 eventConfig,
    bool isL1
  ) public pure returns (DeploymentConfig memory deployConfig) {
    return
      getDeployConfigERC721(
        Constants.holographERC721Hash,
        chainType,
        contractByteCode,
        isL1 ? "Sample ERC721 Contract (localhost)" : "Sample ERC721 Contract (localhost2)",
        "SMPLR",
        eventConfig, //eventConfig
        1000, //royalty
        getInitCodeSampleErc721()
      );
  }

  function getERC721WithConfigDropERC721V2(
    uint32 chainType,
    bytes memory contractByteCode,
    bytes32 eventConfig,
    bool isL1
  ) public pure returns (DeploymentConfig memory deployConfig) {
    SalesConfiguration memory salesConfiguration = SalesConfiguration({
      publicSaleStart: 0,
      publicSaleEnd: 0,
      presaleStart: 0,
      presaleEnd: 0,
      publicSalePrice: 0,
      maxSalePurchasePerAddress: 0,
      presaleMerkleRoot: Constants.EMPTY_BYTES32
    });

    DropsInitializerV2 memory initializer = DropsInitializerV2({
      initialOwner: Constants.getDeployer(),
      fundsRecipient: payable(Constants.getDeployer()),
      editionSize: 0,
      royaltyBPS: 1000,
      salesConfiguration: salesConfiguration,
      metadataRenderer: Constants.getEditionsMetadataRendererProxy(),
      metadataRendererInit: abi.encode("decscription", "imageURI", "animationURI")
    });

    deployConfig.contractType = Constants.contractTypeHolographDropERC721V2;
    deployConfig.chainType = chainType; //holograph id
    deployConfig.salt = Constants.saltHex;
    deployConfig.byteCode = contractByteCode;
    deployConfig.initCode = abi.encode(initializer);
    return deployConfig;
  }
}
