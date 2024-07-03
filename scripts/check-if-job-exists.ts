import fs from 'fs';
import yargs from 'yargs/yargs';
import { hideBin } from 'yargs/helpers';
import { config } from 'dotenv';
import { Environment } from '@holographxyz/environment';
import { parseAbi, getContract, PublicClient } from 'viem';
import { Config, Providers, HolographConfig } from '@holographxyz/sdk';

config();

/**
 * This check if a list of jobs exists.
 *
 * Usage:
 *  1. set HOLOGRAPH_ENVIRONMENT=mainnet
 *  2. set the environmental rpc variables
 *  3. create a json file that contains the following format: {jobHash: string; chainId: number}[]
 *  4. run: `ts-node scripts/find-job-info.ts <JSON_FILE.json>`
 *
 * Example:
 * `ts-node scripts/check-if-job-exists.ts jobs-list.json
 *
 */

type Hex = `0x${string}`;

type Job = {
  jobHash: Hex;
  chainId: number;
};

type JobExists = Job & {
  doesOperatorJobExists: boolean;
  doesFailedJobExists: boolean;
};

const protocolConfig: HolographConfig = {
  networks: {
    ethereum: process.env.ETHEREUM_RPC_URL,
    polygon: process.env.POLYGON_RPC_URL, // 137
    avalanche: process.env.AVALANCHE_RPC_URL, // 43114
    binanceSmartChain: process.env.BINANCE_SMART_CHAIN_RPC_URL, // 56
    arbitrumOne: process.env.ARBITRUM_ONE_RPC_URL, // 42161
    optimism: process.env.OPTIMISM_RPC_URL, // 10
    mantle: process.env.MANTLE_RPC_URL, // 5000
    zora: process.env.ZORA_RPC_URL, // 7777777
    base: process.env.BASE_RPC_URL, // 8453
    linea: process.env.LINEA_RPC_URL,
  },
  environment: Environment.mainnet,
};

// @ts-ignore
const abi = parseAbi([
  'function operatorJobExists(bytes32 jobHash) view returns (bool)',
  'function failedJobExists(bytes32 jobHash) view returns (bool)',
]);

const OPERATOR_CONTRACT_ADDRESS = '0xE1dD53589c001982d06247E1259DCC366b8DdB1B';

async function main() {
  const args = yargs(hideBin(process.argv)).options({
    file: {
      type: 'string',
      describe: 'file path',
      usage: 'Usage: ts-node scripts/check-if-job-exists.ts --file [JSON_FILE.json]',
      require: true,
    },
    chainId: {
      type: 'number',
      describe: 'chain ID to filter jobs',
      usage: 'Usage: ts-node scripts/check-if-job-exists.ts --chainId [CHAIN_ID]',
      require: true,
    },
  }).argv;

  const { file, chainId } = args as {
    file: string;
    chainId: number;
  };

  let rawData = fs.readFileSync(file);
  const jobHashes = JSON.parse(rawData.toString()) as Job[];

  const _ = Config.getInstance(protocolConfig);
  const providers = new Providers();

  let jobExistsList: JobExists[] = [];

  for (const job of jobHashes) {
    if (job.chainId !== chainId) continue; // filter by chainId

    const { jobHash } = job;

    try {
      const provider = providers.byChainId(chainId) as PublicClient;
      // @ts-ignore
      const operatorContract = getContract({ abi, address: OPERATOR_CONTRACT_ADDRESS, client: provider });

      const doesOperatorJobExists = await operatorContract.read.operatorJobExists([jobHash]);
      const doesFailedJobExists = await operatorContract.read.failedJobExists([jobHash]);

      const jobExistsLog = {
        chainId,
        jobHash,
        doesOperatorJobExists,
        doesFailedJobExists,
      };

      jobExistsList.push(jobExistsLog);

      console.log(`Job ${jobHash} on chain ${chainId} exists: ${doesOperatorJobExists} failed: ${doesFailedJobExists}`);
    } catch (error) {
      console.error(error);
    }
  }
}

main().catch(async (e) => {
  console.error(e);
  process.exit(1);
});
