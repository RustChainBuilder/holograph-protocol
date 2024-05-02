import { Contract, Signer, ethers } from 'ethers';
import { LedgerSigner } from '@anders-t/ethers-ledger';
import { JsonRpcProvider, Log, TransactionReceipt, TransactionResponse } from '@ethersproject/providers';
import { parsedEnv } from './env.validation';

require('dotenv').config();

/**
 * Check out the README file
 */

async function main() {
  /*
   * STEP 1: LOAD SENSITIVE INFORMATION SAFELY
   */

  const privateKey = parsedEnv.PRIVATE_KEY;
  const providerURL = parsedEnv.CUSTOM_ERC721_PROVIDER_URL;
  const isHardwareWalletEnabled = parsedEnv.HARDWARE_WALLET_ENABLED;

  const provider: JsonRpcProvider = new JsonRpcProvider(providerURL);

  let deployer: Signer;
  if (isHardwareWalletEnabled) {
    deployer = new LedgerSigner(provider, "44'/60'/0'/0/0");
  } else {
    deployer = new ethers.Wallet(privateKey, provider);
  }

  /*
   * STEP 2: SET HARDCODED VALUES
   */

  const contractAddress = '0xc4535d9a032c0f3ef3c6e03a35d7444de9083148';
  const recipient = '0xD17e8cEe2EC7fEE30e9F9ECB82EaB918659872AF';
  const quantity = 1;

  /*
   * STEP 3: CREATE THE TX
   */

  const countdownERC721ABI = ['function mintTo(address recipient, uint256 quantity) external returns (uint256)'];
  const countdownErc721Contract = new Contract(contractAddress, countdownERC721ABI, deployer);

  let tx: TransactionResponse;
  try {
    tx = await countdownErc721Contract.mintTo(recipient, quantity);
  } catch (error) {
    throw new Error(`Failed to create transaction.`, { cause: error });
  }

  console.log('Transaction:', tx.hash);
  const receipt: TransactionReceipt = await tx.wait();

  if (receipt?.status === 1) {
    console.log('The transaction was executed successfully! Getting the Token ID from logs... ');

    const nftMintedTopic = '0x3a8a89b59a31c39a36febecb987e0657ab7b7c73b60ebacb44dcb9886c2d5c8a';
    const nftMintedLog: Log | undefined = receipt.logs.find((log: Log) => log.topics[0] === nftMintedTopic);

    if (nftMintedLog) {
      const recipient = nftMintedLog.topics[1];
      const tokenID = nftMintedLog.topics[2];

      console.log(`Successfully minted token ID ${tokenID} to address ${recipient}!`);
    } else {
      console.warn('WARN: Failed to extract the Token ID from the transaction receipt.');
    }
  } else {
    throw new Error('Failed to confirm the transaction.');
  }

  console.log(`The transaction was executed successfully! Exiting script ✅\n`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
