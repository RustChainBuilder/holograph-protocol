export function printProgressBar(current: number, total: number, message: string) {
  const progress = total === 0 ? 100 : Math.round((current / total) * 100);
  const progressBar =
    '='.repeat(Math.floor(progress / 5)) + (progress % 5 !== 0 ? '>' : '') + ' '.repeat(20 - Math.ceil(progress / 5));
  console.log(`[${progressBar}] ${message} (${progress}% complete)`);
}

const MAX_RETRIES = 10;

export async function withRetries<T>(func: () => Promise<T>, retries = MAX_RETRIES): Promise<T> {
  try {
    return await func();
  } catch (error) {
    if (retries > 0) {
      console.log(`Error occurred, retrying... Remaining retries: ${retries}`);
      return await withRetries(func, retries - 1);
    }
    throw error;
  }
}

export async function processEventsConcurrently(
  events: any[],
  func: any,
  completedCounter = 0,
  concurrencyLevel = 100
) {
  // Initializing an array to store the results of the processed events
  const results = [];
  // Resetting the global completedCounter
  completedCounter = 0;

  // The total number of events to be processed
  const totalLength = events.length;

  let nextEventIndex = concurrencyLevel;

  // Create an array of Promises for processing the first batch of events.
  // The number of events in the batch is defined by concurrencyLevel.
  // Each Promise is created by calling the provided function (func) on an event.
  const promises = events.slice(0, concurrencyLevel).map((item, index) => func(item, index, totalLength));

  // Keep processing events until all promises are resolved.
  while (promises.length > 0) {
    // Promise.race is used to find the index of the Promise that settles first.
    // This allows us to process events concurrently, but still keep track of the order in which they complete.
    const promiseIndex = await Promise.race(
      promises.map((p: any, index) =>
        p.then(
          (value: any) => ({ value, index }), // Upon successful completion, return value and index
          (error: any) => ({ error, index }) // Upon failure, return error and index
        )
      )
    );

    // Once a Promise has settled, remove it from the list.
    promises.splice(promiseIndex.index, 1);

    // Add the result of the completed Promise to the results array.
    results.push(promiseIndex.value);

    // If there are still unprocessed events, start processing the next one
    if (nextEventIndex < totalLength) {
      const nextEvent = events[nextEventIndex++];
      promises.push(func(nextEvent, results.length, totalLength));
    }
  }

  // After all events have been processed, return the results
  return results;
}

export async function processInBatches({
  start,
  end,
  action,
  initialBatchSize,
  minBatchSize,
  increaseRate = 0.1,
}: {
  start: number;
  end: number;
  action: (range: [number, number]) => Promise<void>;
  initialBatchSize: number;
  minBatchSize: number;
  increaseRate?: number;
}): Promise<void> {
  let batchSize = initialBatchSize;
  let i = start;

  while (i <= end) {
    try {
      const rangeEnd = Math.min(i + batchSize - 1, end);
      await action([i, rangeEnd]);
      i += batchSize;

      if (batchSize < initialBatchSize) {
        batchSize = Math.min(initialBatchSize, Math.floor(batchSize * (1 + increaseRate)));
        console.log(`Increased batch size to ${batchSize}`);
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.log(`Error occurred while processing range ${i} to ${i + batchSize - 1}: ${errorMessage}`);

      batchSize = Math.floor(batchSize / 2);

      if (batchSize < minBatchSize) {
        console.log('Batch size is too small, cannot proceed further.');
        throw error;
      }

      console.log(`Reduced batch size to ${batchSize}, retrying...`);
    }
  }
}
