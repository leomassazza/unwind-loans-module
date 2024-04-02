# unwind-loans-module

**Welcome to unwind-loans-module!**

This repository houses the contracts needed to enable the module to unwind and deprecate v2 legacy loans and wrappers as proposed in [SCCP-2095: Deprecate V2 Legacy Loans / Wrappers](https://sips.synthetix.io/sips/sip-2095/).


## Development

```bash
git clone git@github.com:leomassazza/unwind-loans-module.git
cd ./unwind-loans-module

# Install all dependencies.
npm i 

# Compile contracts via Hardhat
npm run compile
```

## Test module

There's a script to verify the module functionality. In order to use it, fork optimism network with hardhat (i.e. in a Synthetix repo, `npm run fork:ovm`) and execute.

```bash
npx hardhat run ./scripts/testRiskControlModule.js
```

## Implementation notes

xxxx TBD

