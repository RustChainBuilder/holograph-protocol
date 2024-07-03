import * as fs from 'fs';
import { createReadStream, createWriteStream } from 'fs';
import { createInterface } from 'readline';
import { getOperator } from './utils';
import { printProgressBar, processEventsConcurrently, processInBatches } from '../utils/concurrency';

const BATCH_SIZE = 10000; // Adjust batch size as needed
const CONCURRENCY_LEVEL = 1000;

async function checkIfJobsExistOnChain(): Promise<void> {
  const startTime = Date.now();
  const readStream = createReadStream('final_failed_jobs.csv', { encoding: 'utf8' });
  const writeStream = createWriteStream('final_failed_jobs_output.csv', { encoding: 'utf8' });
  const rl = createInterface({ input: readStream });
  const jobs: string[] = [];
  let totalJobs = 0;
  let processedJobs = 0;

  // Read the header
  let csvHeader = 'jobHash,txHash,payload,chainId\n';
  writeStream.write(csvHeader);

  rl.on('line', (line) => {
    if (totalJobs > 0) {
      // Skip the header
      jobs.push(line);
    }
    totalJobs++;
  });

  await new Promise<void>((resolve) => rl.on('close', resolve));

  async function processJob(job: string): Promise<string | null> {
    const [jobHash, , , chainIdStr] = job.split(',');
    const chainId = parseInt(chainIdStr);
    const operator = getOperator(chainId);

    let jobExists = false;

    try {
      const [operatorJobExists, failedJobExists] = await Promise.all([
        operator.operatorJobExists(jobHash) as Promise<boolean>,
        operator.failedJobExists(jobHash) as Promise<boolean>,
      ]);
      jobExists = operatorJobExists || failedJobExists;
    } catch (e) {
      console.log(`🔴 Error while checking job with hash ${jobHash} on chain ${chainId}`);
      return null;
    }

    if (jobExists) {
      console.log(`🟢 Job with hash ${jobHash} exists on chain ${chainId}`);
      return job;
    } else {
      console.log(`🔴 Job with hash ${jobHash} does not exist on chain ${chainId}`);
      return null;
    }
  }

  async function processBatch(range: [number, number]): Promise<void> {
    const [batchStart, batchEnd] = range;
    const batch = jobs.slice(batchStart, batchEnd + 1);
    const validJobs = await processEventsConcurrently(batch, processJob, 0, CONCURRENCY_LEVEL);

    if (validJobs.length > 0) {
      writeStream.write(validJobs.filter((job) => job !== null).join('\n') + '\n');
    }

    processedJobs += batch.length;
    printProgressBar(processedJobs, totalJobs, `Processing jobs ${processedJobs}/${totalJobs}`);
  }

  await processInBatches({
    start: 0,
    end: jobs.length - 1,
    action: processBatch,
    initialBatchSize: BATCH_SIZE,
    minBatchSize: 10,
    increaseRate: 0.1,
  });

  writeStream.end();
  const endTime = Date.now();
  const elapsedTime = endTime - startTime;
  const elapsedMinutes = Math.floor(elapsedTime / 60000);
  const elapsedSeconds = Math.floor((elapsedTime % 60000) / 1000);
  console.log(`\n✅ Processing complete. Output written to final_failed_jobs_output.csv`);
  console.log(`⏱️ Total elapsed time: ${elapsedMinutes} minutes and ${elapsedSeconds} seconds`);
}

async function main() {
  await checkIfJobsExistOnChain();
}

main();
