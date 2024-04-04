const hre = require('hardhat');
const ethers = hre.ethers;

const {
  SNX_COLLATERAL_ETH_ADDRESS,
  SNX_PDAO_MULTISIG_ADDRESS,
  DEPLOYER_ADDRESS,
} = require('../utils/constants.js');

const safeABI = require('../abi/safe.json');
const collateralEthABI = require('../abi/collateralEth.json');

const { impersonateAccount } = require('../utils/helpers.js');

const impersonateSigners = async (provider, safeContract) => {
  const signersAdresses = await safeContract.getOwners();
  const impersonatedSigners = [];
  for (const signerAddress of signersAdresses) {
    impersonatedSigners.push(await impersonateAccount(signerAddress, provider, ethers));
  }
  const safeSigner = await impersonateAccount(safeContract.address, provider, ethers);
  const deployerSigner = await impersonateAccount(DEPLOYER_ADDRESS, provider, ethers);

  return { impersonatedSigners, safeSigner, deployerSigner };
};

const getContracts = async (owner, moduleConfig, moduleAddress = undefined) => {
  const safeContract = new ethers.Contract(SNX_PDAO_MULTISIG_ADDRESS, safeABI, owner);
  const collateralEth = new ethers.Contract(
    SNX_COLLATERAL_ETH_ADDRESS,
    collateralEthABI,
    owner
  );

  let gnosisModule;

  if (moduleAddress) {
    const moduleArtifact = await hre.artifacts.readArtifact(
      'contracts/UnwindLoansModule.sol:UnwindLoansModule'
    );
    gnosisModule = new ethers.Contract(moduleAddress, moduleArtifact.abi, owner);
  } else {
    // deploy one instance
    const GnosisModule = await hre.ethers.getContractFactory('UnwindLoansModule', owner);
    gnosisModule = await GnosisModule.deploy(owner.address, owner.address);
    await gnosisModule.deployed();
  }

  return {
    safeContract,
    collateralEth,
    gnosisModule,
  };
};

module.exports = {
  impersonateSigners,
  getContracts,
};
