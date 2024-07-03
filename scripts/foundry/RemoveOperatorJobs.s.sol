// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {HolographOperator} from "src/HolographOperator.sol";
import {StringUtils} from "scripts/foundry/utils/String.utils.sol";
import {Transaction} from "scripts/foundry/structs/Transaction.struct.sol";
import {Strings} from "src/drops/library/Strings.sol";

import "forge-std/Script.sol";

contract RemoveOperatorJobs is Script {
  using Strings for uint256;

  HolographOperator public operator;
  uint256 public ethFork;
  uint256 public bscFork;
  uint256 public polygonFork;
  uint256 public arbitrumFork;
  uint256 public avalancheFork;
  uint256 public optimismFork;
  uint256 public baseFork;
  uint256 public zoraFork;
  uint256 public mantleFork;

  string public ethSafeJson;
  string public bscSafeJson;
  string public polygonSafeJson;
  string public arbitrumSafeJson;
  string public avalancheSafeJson;
  string public optimismSafeJson;
  string public baseSafeJson;
  string public zoraSafeJson;
  string public mantleSafeJson;

  bytes32[] public ethJobHashes;
  bytes32[] public bscJobHashes;
  bytes32[] public polygonJobHashes;
  bytes32[] public arbitrumJobHashes;
  bytes32[] public avalancheJobHashes;
  bytes32[] public optimismJobHashes;
  bytes32[] public baseJobHashes;
  bytes32[] public zoraJobHashes;
  bytes32[] public mantleJobHashes;
  bytes32[] public tempJobHashesArray;

  Transaction public ethTx;
  Transaction public bscTx;
  Transaction public polygonTx;
  Transaction public arbitrumTx;
  Transaction public avalancheTx;
  Transaction public optimismTx;
  Transaction public baseTx;
  Transaction public zoraTx;
  Transaction public mantleTx;

  constructor() {
    // ethFork = vm.createFork(getRpcUrl(1));
    // bscFork = vm.createFork(getRpcUrl(56));
    // polygonFork = vm.createFork(getRpcUrl(137));
    // arbitrumFork = vm.createFork(getRpcUrl(42161));
    // avalancheFork = vm.createFork(getRpcUrl(43114));
    // optimismFork = vm.createFork(getRpcUrl(10));
    // baseFork = vm.createFork(getRpcUrl(5000));
    // zoraFork = vm.createFork(getRpcUrl(7777777));
    // mantleFork = vm.createFork(getRpcUrl(8453));
  }

  function run() external {
    // Get the operator address from the environment
    operator = HolographOperator(payable(vm.envAddress("HOLOGRAPH_OPERATOR")));

    // Read the CSV file line by line
    string memory jobs = vm.readFile("final_incomplete_jobs.csv");
    string[] memory lines = StringUtils.split(jobs, "\n");

    uint256 currentBatch = 0;
    for (uint i = 1; i < lines.length; i++) {
      /* --------------------------- Decode the cs file --------------------------- */
      string[] memory columns = StringUtils.split(lines[i], ",");
      if (bytes(columns[0]).length != 66) {
        continue;
      }

      bytes32 jobHash = StringUtils.stringToBytes32(columns[0]);
      uint256 chainId = StringUtils.stringToUint256(columns[3]);

      /* ------------- Push the job hashes to the transactions array -------------- */
      if (chainId == 1) {
        ethJobHashes.push(jobHash);
      } else if (chainId == 10) {
        optimismJobHashes.push(jobHash);
      } else if (chainId == 56) {
        bscJobHashes.push(jobHash);
      } else if (chainId == 137) {
        polygonJobHashes.push(jobHash);
      } else if (chainId == 8453) {
        baseJobHashes.push(jobHash);
      } else if (chainId == 5000) {
        mantleJobHashes.push(jobHash);
      } else if (chainId == 42161) {
        arbitrumJobHashes.push(jobHash);
      } else if (chainId == 43114) {
        avalancheJobHashes.push(jobHash);
      } else if (chainId == 7777777) {
        zoraJobHashes.push(jobHash);
      } else {
        console2.log("Unsupported chainId:", chainId);
      }
    }

    generateJsonFor(1);
    generateJsonFor(10);
    generateJsonFor(56);
    generateJsonFor(137);
    generateJsonFor(8453);
    generateJsonFor(5000);
    generateJsonFor(42161);
    generateJsonFor(43114);
    generateJsonFor(7777777);

    console.log("\n\n\u2705 \x1b[32mSafe JSON files are created successfully.\x1b[0m");
  }

  function generateJsonFor(uint256 chainId) private {
    uint256 batchSize = vm.envUint("JOBS_BATCH_SIZE");
    bytes32[] storage jobHashes = getJobHashes(chainId);

    console2.log("\n\n  \x1b[32m============================================================");
    console2.log("\x1b[35mChain:", getChainName(chainId));
    console2.log("\x1b[32m============================================================");

    uint256 batchId;
    for (uint256 i; i < jobHashes.length; i++) {
      tempJobHashesArray.push(jobHashes[i]);
      
      if ((i % batchSize == 0 && i != 0) || i == jobHashes.length - 1) {
        string memory safeJsonPath = getSafeJsonPath(batchId, chainId);
        Transaction memory transaction = Transaction({
          to: address(vm.envAddress("HOLOGRAPH")),
          value: 0,
          data: abi.encodeWithSignature(
            "adminCall(address,bytes)",
            address(operator),
            abi.encodeWithSignature("deleteMultipleOperatorJobs(bytes32[])", tempJobHashesArray)
          ),
          contractMethod: "adminCall",
          contractInputsValues: ""
        });
        string memory safeJson = StringUtils.encodeSafeJson(chainId, vm.envAddress("SAFE_WALLET"), transaction);

        vm.writeFile(safeJsonPath, safeJson);

        batchId++;
        delete tempJobHashesArray;
      }
    }

    console2.log("\x1b[33mBatch size:\x1b[36m", batchSize);
    console2.log("\x1b[33mSafe json files amount:\x1b[36m", batchId);
    console2.log("\x1b[33mJob amounts:\x1b[36m", jobHashes.length);
    console2.log("\x1b[33m", getChainName(chainId), "safe json files in:\x1b[36m", string(abi.encodePacked("./safeJson/", getChainName(chainId))));
    console2.log("\x1b[32m============================================================\x1b[0m");
  }

  function getForkId(uint256 chainId) internal view returns (uint256) {
    if (chainId == 1) {
      return ethFork;
    } else if (chainId == 10) {
      return optimismFork;
    } else if (chainId == 56) {
      return bscFork;
    } else if (chainId == 137) {
      return polygonFork;
    } else if (chainId == 8453) {
      return baseFork;
    } else if (chainId == 5000) {
      return mantleFork;
    } else if (chainId == 42161) {
      return arbitrumFork;
    } else if (chainId == 43114) {
      return avalancheFork;
    } else if (chainId == 7777777) {
      return zoraFork;
    } else {
      return type(uint256).max; // Unsupported chainId
    }
  }

  function getRpcUrl(uint256 chainId) internal pure returns (string memory) {
    if (chainId == 1) {
      return "https://eth.llamarpc.com";
    } else if (chainId == 10) {
      return "https://optimism.llamarpc.com";
    } else if (chainId == 56) {
      return "https://bsc.llamarpc.com";
    } else if (chainId == 137) {
      return "https://polygon-rpc.com";
    } else if (chainId == 5000) {
      return "https://rpc.mantle.xyz";
    } else if (chainId == 8453) {
      return "https://base.llamarpc.com";
    } else if (chainId == 42161) {
      return "https://arbitrum.llamarpc.com";
    } else if (chainId == 43114) {
      return "https://avalanche-c-chain-rpc.publicnode.com";
    } else if (chainId == 7777777) {
      return "https://rpc.zora.energy";
    } else {
      return ""; // Unsupported chainId
    }
  }

  function getSafeJsonPath(uint256 batchId, uint256 chainId) private returns (string memory) {
    bool dirExists = vm.isDir(string(abi.encodePacked("safeJson/", getChainName(chainId), "/")));

    if (!dirExists) {
      string[] memory inputs = new string[](2);
      inputs[0] = "mkdir";
      inputs[1] = string(abi.encodePacked("safeJson/", getChainName(chainId), "/"));

      vm.ffi(inputs);
    }

    return string(abi.encodePacked("safeJson/", getChainName(chainId), "/", batchId.toString(), "_safe.json"));
  }

  function getChainName(uint256 chainId) private pure returns (string memory) {
    if (chainId == 1) {
      return "ETH";
    } else if (chainId == 10) {
      return "Optimism";
    } else if (chainId == 56) {
      return "BSC";
    } else if (chainId == 137) {
      return "Polygon";
    } else if (chainId == 5000) {
      return "Mantle";
    } else if (chainId == 8453) {
      return "Base";
    } else if (chainId == 42161) {
      return "Arbitrum";
    } else if (chainId == 43114) {
      return "Avalanche";
    } else if (chainId == 7777777) {
      return "Zora";
    } else {
      return ""; // Unsupported chainId
    }
  }

  function getJobHashes(uint256 chainId) private view returns (bytes32[] storage) {
    if (chainId == 1) {
      return ethJobHashes;
    } else if (chainId == 10) {
      return optimismJobHashes;
    } else if (chainId == 56) {
      return bscJobHashes;
    } else if (chainId == 137) {
      return polygonJobHashes;
    } else if (chainId == 8453) {
      return baseJobHashes;
    } else if (chainId == 5000) {
      return mantleJobHashes;
    } else if (chainId == 42161) {
      return arbitrumJobHashes;
    } else if (chainId == 43114) {
      return avalancheJobHashes;
    } else if (chainId == 7777777) {
      return zoraJobHashes;
    } else {
      revert(string(abi.encodePacked("Unsupported chainId: ", chainId.toString())));
    }
  }
}
