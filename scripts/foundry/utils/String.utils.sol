// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Transaction} from "scripts/foundry/structs/Transaction.struct.sol";

library StringUtils {
  /**
   * @notice Splits a string into an array of substrings based on a delimiter.
   * @param s The string to split.
   * @param delimiter The delimiter to use for splitting.
   * @return An array of substrings.
   */
  function split(string memory s, string memory delimiter) internal pure returns (string[] memory) {
    bytes memory b = bytes(s);
    bytes memory delim = bytes(delimiter);
    uint256 count;
    uint256 lastIndex;

    // Count occurrences of the delimiter
    while (lastIndex < b.length) {
      if (equals(delim, slice(b, lastIndex, delim.length))) {
        count++;
        lastIndex += delim.length;
      } else {
        lastIndex++;
      }
    }

    // Initialize the result array with the number of substrings
    string[] memory result = new string[](count + 1);
    uint256 resultIndex;
    lastIndex = 0;

    // Split the string by the delimiter
    while (lastIndex < b.length) {
      uint256 startIndex = lastIndex;
      while (lastIndex < b.length && !equals(delim, slice(b, lastIndex, delim.length))) {
        lastIndex++;
      }
      result[resultIndex++] = string(slice(b, startIndex, lastIndex - startIndex));
      lastIndex += delim.length;
    }

    return result;
  }

  /**
   * @notice Compares two byte arrays for equality.
   * @param a The first byte array.
   * @param b The second byte array.
   * @return True if the byte arrays are equal, false otherwise.
   */
  function equals(bytes memory a, bytes memory b) internal pure returns (bool) {
    if (a.length != b.length) return false;
    for (uint256 i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /**
   * @notice Slices a byte array.
   * @param b The byte array to slice.
   * @param start The starting index of the slice.
   * @param length The length of the slice.
   * @return The sliced byte array.
   */
  function slice(bytes memory b, uint256 start, uint256 length) internal pure returns (bytes memory) {
    bytes memory result = new bytes(length);
    for (uint256 i = 0; i < length; i++) {
      result[i] = b[start + i];
    }
    return result;
  }

  /**
   * @notice Converts a hexadecimal string to a bytes32.
   * @param s The hexadecimal string to convert.
   * @return result The bytes32 representation of the hexadecimal string.
   */
  function stringToBytes32(string memory s) internal pure returns (bytes32 result) {
    bytes memory strBytes = bytes(s);

    // Check for the '0x' prefix and adjust length check accordingly
    uint start = 0;
    if (strBytes.length == 66 && strBytes[0] == "0" && strBytes[1] == "x") {
      start = 2;
    } else if (strBytes.length != 64) {
      revert("Invalid hex string length");
    }

    for (uint i = start; i < start + 64; i++) {
      result |= bytes32(uint256(_fromHexChar(uint8(strBytes[i]))) << (4 * (63 - (i - start))));
    }
  }

  /**
   * @notice Converts a single hex character to its value.
   * @param c The hex character.
   * @return The value of the hex character.
   */
  function _fromHexChar(uint8 c) internal pure returns (uint8) {
    if (bytes1(c) >= bytes1("0") && bytes1(c) <= bytes1("9")) {
      return c - uint8(bytes1("0"));
    }
    if (bytes1(c) >= bytes1("a") && bytes1(c) <= bytes1("f")) {
      return 10 + c - uint8(bytes1("a"));
    }
    if (bytes1(c) >= bytes1("A") && bytes1(c) <= bytes1("F")) {
      return 10 + c - uint8(bytes1("A"));
    }
    revert("Invalid hex character");
  }

  /**
   * @notice Converts a string to a byte array.
   * @param s The string to convert.
   * @return The byte array representation of the string.
   */
  function stringToBytes(string memory s) internal pure returns (bytes memory) {
    bytes memory b = bytes(s);
    return b;
  }

  /**
   * @notice Converts a string to a uint256.
   * @param s The string to convert.
   * @return The uint256 representation of the string.
   */
  function stringToUint256(string memory s) internal pure returns (uint256) {
    bytes memory b = bytes(s);
    uint256 result;
    for (uint256 i = 0; i < b.length; i++) {
      result = result * 10 + (uint8(b[i]) - 48);
    }
    return result;
  }

  /**
   * @notice Converts an address to its ASCII string representation.
   * @param x The address to convert.
   * @return The ASCII string representation of the address.
   */
  function addressToAsciiString(address x) internal pure returns (string memory) {
    bytes memory s = new bytes(40);
    for (uint i = 0; i < 20; i++) {
      bytes1 b = bytes1(uint8(uint(uint160(x)) / (2 ** (8 * (19 - i)))));
      bytes1 hi = bytes1(uint8(b) / 16);
      bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
      s[2 * i] = char(hi);
      s[2 * i + 1] = char(lo);
    }
    return string(s);
  }

  /**
   * @notice Converts a byte to its ASCII character representation.
   * @param b The byte to convert.
   * @return c The ASCII character representation of the byte.
   */
  function char(bytes1 b) internal pure returns (bytes1 c) {
    if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
    else return bytes1(uint8(b) + 0x57);
  }

  /**
   * @notice Converts a uint256 to its string representation.
   * @param _i The uint256 to convert.
   * @return The string representation of the uint256.
   */
  function uint256ToString(uint _i) internal pure returns (string memory) {
    if (_i == 0) {
      return "0";
    }
    uint j = _i;
    uint len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint k = len;
    while (_i != 0) {
      k = k - 1;
      uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
      bstr[k] = bytes1(temp);
      _i /= 10;
    }
    return string(bstr);
  }

  /**
   * @notice Converts a byte array to its hexadecimal string representation.
   * @param data The byte array to convert.
   * @return The hexadecimal string representation of the byte array.
   */
  function bytesToHexString(bytes memory data) internal pure returns (string memory) {
    bytes memory hexChars = "0123456789abcdef";
    bytes memory str = new bytes(2 + data.length * 2);
    str[0] = "0";
    str[1] = "x";
    for (uint i = 0; i < data.length; i++) {
      str[2 + i * 2] = hexChars[uint(uint8(data[i] >> 4))];
      str[3 + i * 2] = hexChars[uint(uint8(data[i] & 0x0f))];
    }
    return string(str);
  }

  /**
   * @notice Converts a bytes32 to its string representation.
   * @param _bytes32 The bytes32 to convert.
   * @return The string representation of the bytes32.
   */
  function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
    uint8 i = 0;
    while (i < 32 && _bytes32[i] != 0) {
      i++;
    }
    bytes memory bytesArray = new bytes(i);
    for (uint8 j = 0; j < i; j++) {
      bytesArray[j] = _bytes32[j];
    }
    return string(bytesArray);
  }

  /**
   * @notice Encodes transaction details into a JSON string for a Gnosis Safe transaction batch.
   * @param chainId The chain ID where the transactions will be executed.
   * @param safeWallet The address of the Gnosis Safe wallet.
   * @param transaction A transaction to encode.
   * @return The JSON string representing the batch of transactions.
   */
  function encodeSafeJson(
    uint256 chainId,
    address safeWallet,
    Transaction memory transaction
  ) internal pure returns (string memory) {
    bytes memory transactionsJson = abi.encodePacked("[");
    transactionsJson = abi.encodePacked(
      transactionsJson,
      '{"to":"0x',
      addressToAsciiString(transaction.to),
      '",',
      '"value":"',
      uint256ToString(transaction.value),
      '",',
      '"data":',
      transaction.data.length > 0 ? string(abi.encodePacked('"', bytesToHexString(transaction.data), '"')) : "null",
      ",",
      '"contractMethod":',
      bytes(transaction.contractMethod).length > 0 ? string(abi.encodePacked('"', transaction.contractMethod, '"')) : "null",
      ",",
      '"contractInputsValues":',
      bytes(transaction.contractInputsValues).length > 0
        ? string(abi.encodePacked('"', transaction.contractInputsValues, '"'))
        : "null",
      "}"
    );
    transactionsJson = abi.encodePacked(transactionsJson, "]");

    string memory json = string(
      abi.encodePacked(
        '{"version":"1.0",',
        '"chainId":"',
        uint256ToString(chainId),
        '",',
        '"createdAt":1718892995512,', // Replace with actual timestamp or a function call to get current timestamp
        '"meta":{"name":"Transactions Batch",',
        '"description":"",',
        '"txBuilderVersion":"1.16.5",',
        '"createdFromSafeAddress":"',
        addressToAsciiString(safeWallet),
        '",',
        '"createdFromOwnerAddress":"",',
        '"checksum":"0xe865216579cdd2b08a24abbc7050996d6aa6133b7c891a135173c455c7645a9a"},', // Ensure checksum is correctly calculated
        '"transactions":',
        transactionsJson,
        "}"
      )
    );

    return json;
  }
}
