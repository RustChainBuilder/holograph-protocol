/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

import "../../abstract/Admin.sol";
import "../../abstract/Initializable.sol";

contract DropsMetadataRendererProxy is Admin, Initializable {
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.dropsMetadataRenderer')) - 1)
   */
  bytes32 constant _dropsMetadataRendererSlot = precomputeslot("eip1967.Holograph.dropsMetadataRenderer");

  constructor() {}

  function init(bytes memory data) external override returns (bytes4) {
    require(!_isInitialized(), "HOLOGRAPH: already initialized");
    (address dropsMetadataRenderer, bytes memory initCode) = abi.decode(data, (address, bytes));
    assembly {
      sstore(_adminSlot, origin())
      sstore(_dropsMetadataRendererSlot, dropsMetadataRenderer)
    }
    (bool success, bytes memory returnData) = dropsMetadataRenderer.delegatecall(
      abi.encodeWithSignature("init(bytes)", initCode)
    );
    bytes4 selector = abi.decode(returnData, (bytes4));
    require(success && selector == Initializable.init.selector, "initialization failed");
    _setInitialized();
    return Initializable.init.selector;
  }

  function getDropsMetadataRenderer() external view returns (address dropsMetadataRenderer) {
    assembly {
      dropsMetadataRenderer := sload(_dropsMetadataRendererSlot)
    }
  }

  function setDropsMetadataRenderer(address dropsMetadataRenderer) external onlyAdmin {
    assembly {
      sstore(_dropsMetadataRendererSlot, dropsMetadataRenderer)
    }
  }

  receive() external payable {}

  fallback() external payable {
    assembly {
      let dropsMetadataRenderer := sload(_dropsMetadataRendererSlot)
      calldatacopy(0, 0, calldatasize())
      let result := delegatecall(gas(), dropsMetadataRenderer, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }
}
