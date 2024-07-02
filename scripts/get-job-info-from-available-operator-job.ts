import fs from 'fs';
import yargs from 'yargs/yargs';
import { hideBin } from 'yargs/helpers';
import { config } from 'dotenv';
import { Environment } from '@holographxyz/environment';
import {
  OperatorContract,
  Config,
  Providers,
  DecodedExecuteJobInput,
  HolographConfig,
  OperatorJob,
  decodeAvailableOperatorJobEvent,
  decodeExecuteJobInput,
} from '@holographxyz/sdk';

config();

/**
 * This script gets all information about a job from a transaction with theAvailableOperatorJob event
 *
 * Usage:
 *  1. set HOLOGRAPH_ENVIRONMENT=mainnet
 *  2. set the environmental rpc variables
 *  3. create a json file with the following format: {hash: string; chainId: number}[]
 *  4. run: `ts-node scripts/find-job-info.ts <JSON_FILE.json>`
 *
 * Example:
 * `ts-node scripts/find-job-info.ts available-operator-job-txs.json
 *
 */

type Hex = `0x${string}`;

type AvailableJobInfo = {
  jobHash: Hex;
  executeJobInput?: DecodedExecuteJobInput;
  jobDetails: OperatorJob;
  tx: Hex;
  chainId: number;
  timestamp: string;
  from: Hex;
  to?: Hex;
  contractAddress?: Hex;
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

async function main() {
  const args = yargs(hideBin(process.argv)).options({
    file: {
      type: 'string',
      describe: 'file path',
      usage: 'Usage: ts-node scripts/get-job-info-from-available-operator-job.ts --file [JSON_FILE.json]',
      require: true,
    },
  }).argv;

  const { file } = args as {
    file: string;
  };

  let rawData = fs.readFileSync(file);
  const availableOperatorJobTxs = JSON.parse(rawData.toString()) as { hash: Hex; chainId: number }[];

  const _ = Config.getInstance(protocolConfig);
  const providers = new Providers();

  const allAvailableJobsInfo: AvailableJobInfo[] = [];

  for (const availableOperatorJobTx of availableOperatorJobTxs) {
    const { chainId, hash } = availableOperatorJobTx;

    const receipt = await providers.getTransactionReceipt(chainId, hash);
    const from = receipt.from.toLowerCase() as Hex;
    const to = receipt.to?.toLowerCase() as Hex;
    const contractAddress = receipt.contractAddress?.toLowerCase() as Hex;
    const blockTime = await providers.getLatestBlockTimestamp(chainId);

    const operatorJobPayloadData = decodeAvailableOperatorJobEvent(receipt);
    const operatorJobHash = operatorJobPayloadData[0].values[0] as Hex;
    const operatorJobPayload = operatorJobPayloadData[0].values[1] as Hex;

    const operatorContract = new OperatorContract();

    const jobDetails = (await operatorContract.getJobDetails(chainId, operatorJobHash)) as unknown as OperatorJob;

    let executeJobInput;
    try {
      executeJobInput = decodeExecuteJobInput(operatorJobPayload);
    } catch (error) {
      console.error(`Failed to decode executeJob input for jobHash ${operatorJobHash} on chain ${chainId}`);
    }

    const availableJobInfo: AvailableJobInfo = {
      jobHash: operatorJobHash,
      executeJobInput,
      jobDetails,
      tx: hash,
      chainId,
      timestamp: new Date(Number(blockTime) * 1000).toUTCString(),
      from,
      to,
      contractAddress,
    };
    allAvailableJobsInfo.push(availableJobInfo);

    //console.log(availableJobInfo)
  }

  const jsonString = JSON.stringify(allAvailableJobsInfo, (_, value) =>
    typeof value === 'bigint' ? value.toString() : value
  );
  fs.writeFile('./scripts/all-available-jobs-info.json', jsonString, (err) => {
    if (err) console.log('Error writing file:', err);
  });
}

main().catch(async (e) => {
  console.error(e);
  process.exit(1);
});
