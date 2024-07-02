import { Network, networks } from '@holographxyz/networks';
import { ethers } from 'ethers';
import * as fs from 'fs';
import * as path from 'path';

require('dotenv').config();

import { hTokenAddresses } from './utils/addresses';

const HOLOGRAPH_ENVIRONMENT = process.env.HOLOGRAPH_ENVIRONMENT || 'mainnet';
const BASE_DIR = `../deployments/${HOLOGRAPH_ENVIRONMENT}`;
const TOKENS = ['hETH', 'hBNB', 'hAVAX', 'hMATIC', 'hMNT'];

async function main() {
  const baseDir = path.join(__dirname, BASE_DIR);
  const deployedNetworks = fs.readdirSync(baseDir)?.map((network) => networks[network]);

  console.log('------------------ Ownership Data ------------------');

  const results = await Promise.all(
    deployedNetworks.map(async (network) => {
      const contracts = fs
        .readdirSync(`${baseDir}/${network.key}`)
        ?.filter((contract) => contract.includes('.json'))
        ?.map((contract) => contract.replace('.json', ''));
      return Promise.all(contracts.map((contract) => getContractOwner(contract, network)));
    })
  );

  const sortedResults = results?.flat()?.sort((a, b) => (a?.network! > b?.network! ? 1 : -1));

  sortedResults?.forEach((result) => {
    if (result?.error) console.log(`(${result?.network}) Error fetching ${result?.contractName} owner`);
    else console.log(`(${result?.network}) ${result?.contractName}: ${result?.owner}`);
  });

  let tokenResults: { contractName: string; owner: string }[] = [];

  for (const token of TOKENS) {
    const holographEnvironment = HOLOGRAPH_ENVIRONMENT === 'mainnet' ? 'mainnet' : 'testnet';
    const rpc = HOLOGRAPH_ENVIRONMENT === 'mainnet' ? networks.ethereum.rpc : networks.ethereumTestnetSepolia.rpc;
    const address = hTokenAddresses?.[holographEnvironment][token as 'hETH' | 'hBNB' | 'hAVAX' | 'hMATIC' | 'hMNT'];

    const contractInstance = new ethers.Contract(
      address!,
      ['function getAdmin() public view returns (address)'],
      new ethers.providers.JsonRpcProvider(rpc)
    );
    const owner = (await contractInstance?.getAdmin?.()) || (await contractInstance?.owner?.());
    tokenResults.push({ contractName: token, owner });

    console.log(`${token}: ${owner}`);
  }

  const allResults = [...sortedResults.filter((result) => !result.error), ...tokenResults];
  const zeroAddressOwner = allResults.filter((result) => result.owner === '0x0000000000000000000000000000000000000000');
  const factoryOwner = allResults.filter((result) => result.owner === '0xf3dDf3Dc6ebB5c5Dc878c7A0c8B2C5e051c37594');
  const genesisOwner = allResults.filter((result) => result.owner === '0x2694a14ea8D91F4CC314A3dBe8819eaadb7E025E');
  const deployerOwner = allResults.filter((result) =>
    [
      '0xBB566182f35B9E5Ae04dB02a5450CC156d2f89c1',
      '0x22ED36947DDd1ae317F7816c410D3c0c58Bb9b90',
      '0xFfCA0d6986099FbDb3b6AD9b6aa5DF5ed1d44f0C',
      '0xDF9013a9Af763b181EF8acFC0e3229494004e001',
      '0x00Ac9Fd50C63f176B49F05FfedA324bD68C7cD69',
    ].includes(result.owner!)
  );

  const fileOutputPath = path.join(__dirname);

  if (zeroAddressOwner?.length)
    fs.writeFileSync(`${fileOutputPath}/zero-address-owner.json`, JSON.stringify(zeroAddressOwner));
  if (factoryOwner?.length) fs.writeFileSync(`${fileOutputPath}/factory-owner.json`, JSON.stringify(factoryOwner));
  if (genesisOwner?.length) fs.writeFileSync(`${fileOutputPath}/genesis-owner.json`, JSON.stringify(genesisOwner));
  if (deployerOwner?.length) fs.writeFileSync(`${fileOutputPath}/deployer-owner.json`, JSON.stringify(deployerOwner));

  console.log('------------------------------------------------');
}

async function getContractOwner(contractName: string, network: Network) {
  try {
    const file = path.join(__dirname, BASE_DIR, network.key, contractName);
    const contractData = JSON.parse(fs.readFileSync(file + '.json', 'utf8'));
    const provider = new ethers.providers.JsonRpcProvider(network.rpc);
    const contractInstance = new ethers.Contract(contractData.address, contractData.abi, provider);
    const owner: string = (await contractInstance?.getAdmin?.()) || (await contractInstance?.owner?.());

    return {
      network: network.name,
      contractName,
      owner,
    };
  } catch {
    return {
      network: network.name,
      contractName,
      error: true,
    };
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
