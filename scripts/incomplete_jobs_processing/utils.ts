import { ethers } from 'ethers';
require('dotenv').config();
import dotenv from 'dotenv';
dotenv.config();

const abi = [
  { type: 'constructor', inputs: [], stateMutability: 'nonpayable' },
  { type: 'fallback', stateMutability: 'payable' },
  { type: 'receive', stateMutability: 'payable' },
  {
    type: 'function',
    name: 'admin',
    inputs: [],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'adminCall',
    inputs: [
      { name: 'target', type: 'address', internalType: 'address' },
      { name: 'data', type: 'bytes', internalType: 'bytes' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'bondUtilityToken',
    inputs: [
      { name: 'operator', type: 'address', internalType: 'address' },
      { name: 'amount', type: 'uint256', internalType: 'uint256' },
      { name: 'pod', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'crossChainMessage',
    inputs: [{ name: 'bridgeInRequestPayload', type: 'bytes', internalType: 'bytes' }],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'deleteFailedJob',
    inputs: [{ name: 'jobHash', type: 'bytes32', internalType: 'bytes32' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'deleteMultipleFailedJobs',
    inputs: [{ name: 'jobHashes', type: 'bytes32[]', internalType: 'bytes32[]' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'deleteMultipleOperatorJobs',
    inputs: [{ name: 'jobHashes', type: 'bytes32[]', internalType: 'bytes32[]' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'deleteOperatorJob',
    inputs: [{ name: 'jobHash', type: 'bytes32', internalType: 'bytes32' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'executeJob',
    inputs: [{ name: 'bridgeInRequestPayload', type: 'bytes', internalType: 'bytes' }],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'failedJobExists',
    inputs: [{ name: 'jobHash', type: 'bytes32', internalType: 'bytes32' }],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getAdmin',
    inputs: [],
    outputs: [{ name: 'adminAddress', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getBondedAmount',
    inputs: [{ name: 'operator', type: 'address', internalType: 'address' }],
    outputs: [{ name: 'amount', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getBondedPod',
    inputs: [{ name: 'operator', type: 'address', internalType: 'address' }],
    outputs: [{ name: 'pod', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getBondedPodIndex',
    inputs: [{ name: 'operator', type: 'address', internalType: 'address' }],
    outputs: [{ name: 'index', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getBridge',
    inputs: [],
    outputs: [{ name: 'bridge', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getHolograph',
    inputs: [],
    outputs: [{ name: 'holograph', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getInterfaces',
    inputs: [],
    outputs: [{ name: 'interfaces', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getJobDetails',
    inputs: [{ name: 'jobHash', type: 'bytes32', internalType: 'bytes32' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        internalType: 'struct OperatorJob',
        components: [
          { name: 'pod', type: 'uint8', internalType: 'uint8' },
          { name: 'blockTimes', type: 'uint16', internalType: 'uint16' },
          { name: 'operator', type: 'address', internalType: 'address' },
          { name: 'startBlock', type: 'uint40', internalType: 'uint40' },
          { name: 'startTimestamp', type: 'uint64', internalType: 'uint64' },
          { name: 'fallbackOperators', type: 'uint16[5]', internalType: 'uint16[5]' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getMessageFee',
    inputs: [
      { name: '', type: 'uint32', internalType: 'uint32' },
      { name: '', type: 'uint256', internalType: 'uint256' },
      { name: '', type: 'uint256', internalType: 'uint256' },
      { name: '', type: 'bytes', internalType: 'bytes' },
    ],
    outputs: [
      { name: '', type: 'uint256', internalType: 'uint256' },
      { name: '', type: 'uint256', internalType: 'uint256' },
      { name: '', type: 'uint256', internalType: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getMessagingModule',
    inputs: [],
    outputs: [{ name: 'messagingModule', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getMinGasPrice',
    inputs: [],
    outputs: [{ name: 'minGasPrice', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getPodBondAmounts',
    inputs: [{ name: 'pod', type: 'uint256', internalType: 'uint256' }],
    outputs: [
      { name: 'base', type: 'uint256', internalType: 'uint256' },
      { name: 'current', type: 'uint256', internalType: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getPodOperators',
    inputs: [
      { name: 'pod', type: 'uint256', internalType: 'uint256' },
      { name: 'index', type: 'uint256', internalType: 'uint256' },
      { name: 'length', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [{ name: 'operators', type: 'address[]', internalType: 'address[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getPodOperators',
    inputs: [{ name: 'pod', type: 'uint256', internalType: 'uint256' }],
    outputs: [{ name: 'operators', type: 'address[]', internalType: 'address[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getPodOperatorsLength',
    inputs: [{ name: 'pod', type: 'uint256', internalType: 'uint256' }],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getRegistry',
    inputs: [],
    outputs: [{ name: 'registry', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getTotalPods',
    inputs: [],
    outputs: [{ name: 'totalPods', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getUtilityToken',
    inputs: [],
    outputs: [{ name: 'utilityToken', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'init',
    inputs: [{ name: 'initPayload', type: 'bytes', internalType: 'bytes' }],
    outputs: [{ name: '', type: 'bytes4', internalType: 'bytes4' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'jobEstimator',
    inputs: [{ name: 'bridgeInRequestPayload', type: 'bytes', internalType: 'bytes' }],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'nonRevertingBridgeCall',
    inputs: [
      { name: 'msgSender', type: 'address', internalType: 'address' },
      { name: 'payload', type: 'bytes', internalType: 'bytes' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'operatorJobExists',
    inputs: [{ name: 'jobHash', type: 'bytes32', internalType: 'bytes32' }],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'send',
    inputs: [
      { name: 'gasLimit', type: 'uint256', internalType: 'uint256' },
      { name: 'gasPrice', type: 'uint256', internalType: 'uint256' },
      { name: 'toChain', type: 'uint32', internalType: 'uint32' },
      { name: 'msgSender', type: 'address', internalType: 'address' },
      { name: 'nonce', type: 'uint256', internalType: 'uint256' },
      { name: 'holographableContract', type: 'address', internalType: 'address' },
      { name: 'bridgeOutPayload', type: 'bytes', internalType: 'bytes' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'setAdmin',
    inputs: [{ name: 'adminAddress', type: 'address', internalType: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setBridge',
    inputs: [{ name: 'bridge', type: 'address', internalType: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setHolograph',
    inputs: [{ name: 'holograph', type: 'address', internalType: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setInterfaces',
    inputs: [{ name: 'interfaces', type: 'address', internalType: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setMessagingModule',
    inputs: [{ name: 'messagingModule', type: 'address', internalType: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setMinGasPrice',
    inputs: [{ name: 'minGasPrice', type: 'uint256', internalType: 'uint256' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setRegistry',
    inputs: [{ name: 'registry', type: 'address', internalType: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setUtilityToken',
    inputs: [{ name: 'utilityToken', type: 'address', internalType: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'topupUtilityToken',
    inputs: [
      { name: 'operator', type: 'address', internalType: 'address' },
      { name: 'amount', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'unbondUtilityToken',
    inputs: [
      { name: 'operator', type: 'address', internalType: 'address' },
      { name: 'recipient', type: 'address', internalType: 'address' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'event',
    name: 'AvailableOperatorJob',
    inputs: [
      { name: 'jobHash', type: 'bytes32', indexed: false, internalType: 'bytes32' },
      { name: 'payload', type: 'bytes', indexed: false, internalType: 'bytes' },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'CrossChainMessageSent',
    inputs: [{ name: 'messageHash', type: 'bytes32', indexed: false, internalType: 'bytes32' }],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'FailedOperatorJob',
    inputs: [{ name: 'jobHash', type: 'bytes32', indexed: false, internalType: 'bytes32' }],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'FinishedOperatorJob',
    inputs: [
      { name: 'jobHash', type: 'bytes32', indexed: false, internalType: 'bytes32' },
      { name: 'operator', type: 'address', indexed: false, internalType: 'address' },
    ],
    anonymous: false,
  },
  { type: 'error', name: 'JobDoesNotExist', inputs: [{ name: 'jobHash', type: 'bytes32', internalType: 'bytes32' }] },
];

export function getOperator(chainId: number) {
  const rpcUrl = getRpcUrl(chainId);
  if (rpcUrl == '') {
    console.log('Unsupported chainId ' + chainId);
  }
  if (process.env.HOLOGRAPH_OPERATOR == undefined) {
    throw new Error('HOLOGRAPH_OPERATOR env variable is not set');
  }

  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
  return new ethers.Contract(process.env.HOLOGRAPH_OPERATOR!, abi, provider);
}

export function isJobNull(job: any) {
  return job[0] == 0 && job[3] == 0 && job[4] == 0;
}

function getRpcUrl(chainId: number): string {
  switch (chainId) {
    case 1:
      return process.env.ETHEREUM_RPC_URL || 'https://eth.llamarpc.com';
    case 10:
      return process.env.OPTIMISM_RPC_URL || 'https://optimism.llamarpc.com';
    case 56:
      return process.env.BINANCE_SMART_CHAIN_RPC_URL || 'https://bsc.llamarpc.com';
    case 137:
      return process.env.POLYGON_RPC_URL || 'https://polygon-rpc.com';
    case 5000:
      return process.env.MANTLE_RPC_URL || 'https://rpc.mantle.xyz';
    case 8453:
      return process.env.BASE_RPC_URL || 'https://base.llamarpc.com';
    case 42161:
      return process.env.ARBITRUM_ONE_RPC_URL || 'https://arbitrum.llamarpc.com';
    case 43114:
      return process.env.AVALANCHE_RPC_URL || 'https://avalanche-c-chain-rpc.publicnode.com';
    case 7777777:
      return process.env.ZORA_RPC_URL || 'https://rpc.zora.energy';
    default:
      return ''; // Unsupported chainId
  }
}
