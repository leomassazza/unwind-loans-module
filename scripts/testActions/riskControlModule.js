const { assertRevert } = require('../utils/helpers.js');
const hre = require('hardhat');
const formatEther = hre.ethers.utils.formatEther;
const { green, red, gray } = require('chalk');

const tickOrCross = pass => (pass ? green('✔') : red('✗'));
const logCheck = (message, expected, fetched) => {
  console.log(
    `${message}: ${tickOrCross(expected === fetched)} ` +
    gray(`(expected: ${expected} fetched: ${fetched})`)
  );

  if (expected !== fetched) {
    throw new Error(`${message} not passed. Expected: ${expected} Current: ${fetched}`);
  }
};

const verifyAndShowParams = async ({
  safeContract,
  gnosisModule,
  collateralEth,
  moduleConfig,
  moduleOwner,
  moduleEnabled = false,
  expectedMCR = undefined,
}) => {
  const fetchedModuleEnabled = await safeContract.isModuleEnabled(gnosisModule.address);
  const fetchedModuleOwner = await gnosisModule.owner();
  const fetchedMCR = await collateralEth.minCratio();
  console.log('fetchedMCR', fetchedMCR.toString());

  if (expectedMCR === undefined) {
    expectedMCR = fetchedMCR;
  }

  console.log('Verifying initial values');
  logCheck('  Module owner', moduleOwner.address, fetchedModuleOwner);
  const fetchedModuleConfig = await checkParams({
    gnosisModule,
    moduleConfig,
  });

  logCheck(`  minCratio      `, formatEther(expectedMCR), formatEther(fetchedMCR));
  logCheck('  Module Enabled ', moduleEnabled, fetchedModuleEnabled);

  return {
    moduleEnabled: fetchedModuleEnabled,
    moduleOwner: fetchedModuleOwner,
    moduleConfig: fetchedModuleConfig,
    minCratio: fetchedMCR,
  };
};

const checkParams = async ({
  gnosisModule,
  moduleConfig,
}) => {
  const fetchedModuleConfig = {
    isPaused: await gnosisModule.isPaused(),
    endorsed: await gnosisModule.endorsedAccount(),
    owner: await gnosisModule.owner(),
  };
  console.log('  Parameters');
  logCheck('    owner', moduleConfig.owner, fetchedModuleConfig.owner);
  logCheck('    endorsed', moduleConfig.endorsed, fetchedModuleConfig.endorsed);
  logCheck('    isPaused', moduleConfig.isPaused, fetchedModuleConfig.isPaused);

  return fetchedModuleConfig;
};

const attemptToControlRisk = async ({
  gnosisModule,
  owner,
  user,
  perpsV2MarketSettings,
  shouldFailNotEnabled = false,
  shouldFailEndorsed = false,
  shouldFailPaused = false,
  shouldFailNotCovered = false,

  marketKey,
}) => {

  if (shouldFailNotEnabled) {
    await assertRevert(gnosisModule.connect(user).unwind(marketKeyBytes), 'GS104');
    return false;
  }

  if (shouldFailEndorsed) {
    await assertRevert(gnosisModule.connect(user).unwind(marketKeyBytes), 'Not endorsed');
    return false;
  }

  if (shouldFailPaused) {
    await assertRevert(gnosisModule.connect(user).unwind(marketKeyBytes), 'Module paused');
    return false;
  }

  if (shouldFailNotCovered) {
    await assertRevert(gnosisModule.connect(user).unwind(marketKeyBytes), 'Market not covered');
    return false;
  }

  const previousValue = await perpsV2MarketSettings.maxMarketValue(marketKeyBytes);
  logCheck('  Previous MMV', formatEther(previousValue), formatEther(previousValue));
  await (await gnosisModule.connect(user).coverRisk(marketKeyBytes)).wait();
  const currentValue = await perpsV2MarketSettings.maxMarketValue(marketKeyBytes);
  logCheck('  New MMV', formatEther(0), formatEther(currentValue));

  return true;
};

module.exports = {
  logCheck,
  checkParams,
  verifyAndShowParams,
  attemptToControlRisk,
};
