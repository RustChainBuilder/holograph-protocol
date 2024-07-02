import * as jobs from '../all-available-jobs-info.json';
import * as fs from 'fs';
import { createReadStream, createWriteStream } from 'fs';
import { createInterface } from 'readline';
import { getOperator } from './utils';
import { printProgressBar } from '../utils/concurrency';

async function checkFileExistence() {
  if (!fs.existsSync('scripts/incomplete_jobs_processing/indexer-incomplete-jobs.csv')) {
    console.log(
      '❌ File scripts/incomplete_jobs_processing/indexer-incomplete-jobs.csv should exist and contains all the jobs founded by the indexer.'
    );
    process.exit(1);
  }

  if (!fs.existsSync('./scripts/all-available-jobs-info.json')) {
    console.log(
      '❌ File ./scripts/all-available-jobs-info.json should exist and contains the result of the `get-job-info-from-available-operator-job.ts` script.'
    );
    process.exit(1);
  }
}

async function processJson() {
  const filteredJobsKey = Object.keys(jobs).filter((jobKey: any) => {
    const job: any = jobs[jobKey];
    return job.jobHash != undefined && job.chainId != undefined;
  });

  const csvHeader = 'jobHash,txHash,payload,chainId\n';
  let csv = csvHeader;

  filteredJobsKey.forEach((jobKey: any, index: number) => {
    const job: any = jobs[jobKey];
    csv = csv.concat(`${job.jobHash},${job.tx},0x00,${job.chainId}${index == filteredJobsKey.length - 1 ? '' : '\n'}`);
  });

  fs.writeFileSync('final_incomplete_jobs.csv', csv);
}

function checkJobsExistance() {
  const finalJobs = fs
    .readFileSync('./scripts/incomplete_jobs_processing/indexer-incomplete-jobs.csv', 'utf8')
    .split('\n');

  // add the missing jobs in the final csv
  let csv = 'jobHash,txHash,payload,chainId\n';

  finalJobs.forEach((job, index: number) => {
    if (index == 0) return;
    let jobHash = job.split(',')[0];
    let chainId = job.split(',')[3];
    csv = csv.concat(`${jobHash},0x00,0x00,${chainId}${index == finalJobs.length - 1 ? '' : '\n'}`);
  });

  fs.writeFileSync('final_incomplete_jobs.csv', csv);

  console.log(`✅ CSV file for foundry generated successfully.`);
}

const BATCH_SIZE = 100; // Adjust batch size as needed
const CONCURRENCY_LEVEL = 10;

async function checkIfJobsExistOnChain(): Promise<void> {
  const readStream = createReadStream('final_incomplete_jobs.csv', { encoding: 'utf8' });
  const writeStream = createWriteStream('final_incomplete_jobs_output.csv', { encoding: 'utf8' });
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

  const processBatch = async (batch: string[]): Promise<string[]> => {
    const results: string[] = [];
    const executing: Promise<void>[] = [];

    for (const job of batch) {
      const promise = processJob(job)
        .then((result) => {
          if (result !== null) {
            results.push(result);
          }
        })
        .catch((e) => {
          console.log(`🔴 Error processing job: ${e}`);
        });

      executing.push(promise);

      if (executing.length >= CONCURRENCY_LEVEL) {
        await Promise.race(executing);
        executing.splice(0, 1); // Remove the resolved promise
      }
    }

    await Promise.all(executing);

    return results;
  };

  for (let i = 0; i < jobs.length; i += BATCH_SIZE) {
    const batch = jobs.slice(i, i + BATCH_SIZE);
    const validJobs = await processBatch(batch);

    if (validJobs.length > 0) {
      writeStream.write(validJobs.join('\n') + '\n');
    }

    processedJobs += batch.length;
    printProgressBar(processedJobs, totalJobs, `Processing jobs ${processedJobs}/${totalJobs}`);
  }

  writeStream.end();
  console.log(`\n✅ Processing complete. Output written to final_incomplete_jobs_output.csv`);
}

async function main() {
  await checkFileExistence();
  await checkJobsExistance();
  await checkIfJobsExistOnChain();
}

main();
