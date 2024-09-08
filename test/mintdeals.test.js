import TronWeb from 'tronweb';
import { expect } from 'chai';
import { config } from './nile-config.js';
import 'dotenv/config';

const tronWeb = new TronWeb({
  fullHost: "https://nile.trongrid.io",
  privateKey: process.env.PRIVATE_KEY_NILE
});

const USDD_DECIMALS = 18;
const USDT_DECIMALS = 8;
const BTC_DECIMALS = 6;

async function getContract(address) {
  console.log(`Getting contract for address: ${address}`);
  try {
    const contract = await tronWeb.contract().at(address);
    console.log(`Contract at ${address} retrieved successfully.`);
    return contract;
  } catch (error) {
    console.error(`Failed to get contract for address: ${address}`, error);
    throw error;
  }
}

//optional converter
async function toSun(amount, decimals) {
  const value = tronWeb.toBigNumber(amount.toString()) // Convert amount to string to handle large numbers
    .multipliedBy(tronWeb.toBigNumber(10).pow(decimals)) // Handle the decimal conversion
    .toFixed(); // Convert the BigNumber to a string with no decimal places

  console.log(`Converted value: ${value}`); // Debugging
  return value;
}


describe('MintDeals Contract Automation', function () {
  this.timeout(10000); // Increase timeout to 10 seconds

  let USDDAddress, USDTAddress, BTCAddress;
  let creditFacility, creditManager, clubDealRegistry, mintDealsNFT;

  before(async function () {
    this.timeout(10000);
    USDDAddress = await getContract(config.USDDAddress);
    USDTAddress = await getContract(config.USDTAddress);
    BTCAddress = await getContract(config.BTCAddress);
    creditFacility = await getContract(config.CreditFacilityAddress);
    creditManager = await getContract(config.CreditManagerAddress);
    clubDealRegistry = await getContract(config.ClubDealRegistryAddress);
    mintDealsNFT = await getContract(config.MintDealsNFTAddress);
  });


  it('should approve credit facility and manager and registry to spend USDD and USDT and BTC', async function () {
    this.timeout(10000);
    
    // console.log('Approving USDD for CreditFacility');
    // await USDDAddress.approve(config.CreditFacilityAddress,  await toSun(9000, USDD_DECIMALS)).send();
    // console.log('USDD approved');

    // console.log('Approving USDT for CreditFacility');
    // await USDTAddress.approve(config.CreditFacilityAddress, await toSun(500, USDT_DECIMALS)).send();
    // console.log('USDT approved');

    // console.log('Approving BTC for CreditFacility');
    // await BTCAddress.approve(config.CreditFacilityAddress, await toSun(10, BTC_DECIMALS)).send();
    // console.log('BTC approved');

    // console.log('Approving USDD for CreditManager');
    // await USDDAddress.approve(config.CreditManagerAddress, await toSun(9000, USDD_DECIMALS)).send();
    // console.log('USDD approved for CreditManager');

    // console.log('Approving BTC for CreditManager');
    // await BTCAddress.approve(config.CreditManagerAddress, await toSun(10, BTC_DECIMALS)).send();
    // console.log('BTC approved for CreditManager');

    // console.log('Approving USDD for ClubDealRegistry');
    // await USDDAddress.approve(config.ClubDealRegistryAddress, await toSun(1000, USDD_DECIMALS)).send();
    // console.log('USDD approved for ClubDealRegistry');
    
    // console.log('Approving USDT for ClubDealRegistry');
    // await USDTAddress.approve(config.ClubDealRegistryAddress, await toSun(1000, USDT_DECIMALS)).send();
    // console.log('USDT approved for ClubDealRegistry');
  });

  it('should add cToken info for USDD, USDT, BTC', async function () {
    this.timeout(10000);

  //   console.log('Adding USDD cToken');
  //   await creditFacility.addCToken(config.USDDCTokenAddress, config.USDDAddress, true, config.USDDOracle).send();
  //   console.log('USDD cToken added');

  //   console.log('Adding USDT cToken');
  //   await creditFacility.addCToken(config.USDTCTokenAddress, config.USDTAddress, true, config.USDTOracle).send();
  //   console.log('USDT cToken added');

  //   console.log('Adding BTC cToken');
  //   await creditFacility.addCToken(config.BTCCTokenAddress, config.BTCAddress, false, config.BTCOracle).send();
  //   console.log('BTC cToken added');
  });

  it('should supply assets and perform borrow/repay operations', async function() {
    this.timeout(10000);

    // console.log('Supplying USDD');
    // await creditFacility.supplyAsset(config.USDDCTokenAddress, await toSun(1000, USDD_DECIMALS), config.Beneficiary1).send();
    // console.log('USDD supplied');

    // console.log('Supplying USDT');
    // await creditFacility.supplyAsset(config.USDTCTokenAddress, await toSun(400, USDT_DECIMALS), config.Beneficiary1).send();
    // console.log('USDT supplied');

    // console.log('Supplying BTC');
    // await creditFacility.supplyAsset(config.BTCCTokenAddress, "await toSun(1, BTC_DECIMALS), config.Beneficiary1).send();
    // console.log('BTC supplied');

    // console.log('Enabling USDD as collateral');
    // await creditFacility.enableAsCollateral(config.USDDCTokenAddress).send();
    // console.log('USDD enabled as collateral');

    // console.log('Enabling USDT as collateral');
    // await creditFacility.enableAsCollateral(config.USDTCTokenAddress).send();
    // console.log('USDT enabled as collateral');

    // console.log('Enabling BTC as collateral');
    // await creditFacility.enableAsCollateral(config.BTCCTokenAddress).send();
    // console.log('BTC enabled as collateral');

    // console.log('Borrowing USDD');
    // await creditFacility.borrow(config.USDDCTokenAddress, await toSun(538, USDD_DECIMALS)).send();
    // console.log('USDD borrowed');

    // console.log('Repaying USDD borrow');
    // await creditFacility.repayBorrow(config.USDDCTokenAddress, await toSun(350, USDD_DECIMALS), config.Beneficiary1).send();
    // console.log('USDD borrow repaid');
  });

  //ClubDealRegistry
  it('should set the club creation fee to $12 USDD', async function () {
    // this.timeout(10000);
  
    // const creationFee = await toSun(12, USDD_DECIMALS); // Convert $12 to USDD value
    // console.log(`Setting club creation fee to: ${creationFee} (in smallest USDD units)`);
  
    // await clubDealRegistry.setClubCreationFee(creationFee).send();
    // console.log('Club creation fee set successfully.');
  });
  

  it('should create 2 clubs with USDD and USDT as payment tokens', async function () {
    // this.timeout(10000);
  
    // const club1Fee = await toSun(50, USDD_DECIMALS); // $50 for club 1
    // const club2Fee = await toSun(45, USDD_DECIMALS); // $45 for club 2
  
    // console.log('Creating club 1 with USDD as payment token');
    // await clubDealRegistry.createClub(
    //   config.USDDAddress, // Payment token is USDD
    //   club1Fee,           // Club fee
    //   true                // Send to credit facility flag
    // ).send();
    // console.log('Club 1 created successfully.');
  
    // console.log('Creating club 2 with USDT as payment token');
    // await clubDealRegistry.createClub(
    //   config.USDTAddress, // Payment token is USDT
    //   club2Fee,           // Club fee
    //   true                // Send to credit facility flag
    // ).send();
    // console.log('Club 2 created successfully.');
  });

  it('should add a member to the club using USDD as the payment token', async function () {
    // this.timeout(10000);
  
    // const memberAddress = 'TLHKdCL7MiwT73rBrq8TXnANZ4VKH1P3kt'; // Member's Tron address
  
    // console.log(`Adding member ${memberAddress} to club with USDD as payment token`);
    // await clubDealRegistry.addClubMember(
    //   1,    // ClubId
    //   memberAddress,         // Member address
    //   config.USDDAddress   // Payment token is USDD
    // ).send();
    // console.log('Member added successfully with USDD.');

    // console.log(`Adding member ${memberAddress} to club with USDT as payment token`);
    // await clubDealRegistry.addClubMember(
    //   2,    // ClubId
    //   memberAddress,         // Member address
    //   config.USDTAddress   // Payment token is USDT
    // ).send();
    // console.log('Member added successfully with USDT.');

  });
  
  
  //CreditManager
  // it('should execute score steps (borrow 4 + repay 6)', async function () {
  //   this.timeout(10000);
    
  //   console.log('Executing ScoreSteps (Borrow 4, Repay 6)');
  //   await creditManager.setScoreSteps(4, 6).send();
  //   console.log('ScoreSteps executed (borrow 4 + repay 6)');
  // });
  
  // it('should supply 1 BTC with beneficiary as creditManagerAddress', async function () {
  //   this.timeout(10000);
  
  //   console.log('Supplying 1 BTC');
  //   await creditFacility.supplyAsset(config.BTCCTokenAddress, await toSun(1, BTC_DECIMALS), config.CreditManagerAddress).send();
  //   console.log('1 BTC supplied to CreditFacility on behalf of CreditManagerAddress');
  // });
  
  // it('should update global max credit limit for BTC cToken', async function () {
  //   this.timeout(10000);
  
  //   console.log('Updating Global Max Credit Limit for BTC cToken');
  //   await creditManager.updateGlobalMaxCreditLimit(config.BTCCTokenAddress).send();
  //   const globalCreditLimit = await creditManager.globalMaxCreditLimit().call();
  //   console.log(`Global Max Credit Limit for BTC updated to ${globalCreditLimit.toString()}`);
  // });
  
  it('should borrow 300 USDD from CreditManager', async function () {
    this.timeout(10000);
  
    console.log('Borrowing 500 USDD');
    await creditManager.borrow(config.USDDAddress, await toSun(500, USDD_DECIMALS)).send();
    const creditInfo = await creditManager.getCreditInfo(config.Beneficiary1).call();
    console.log(`500 USDD borrowed - Credit Info is now ${creditInfo}`);
  });
  
  it('should repay 150 USDD to CreditManager', async function () {
    this.timeout(10000);
  
    console.log('Repaying 150 USDD');
    await creditManager.repay(config.USDDAddress, await toSun(150, USDD_DECIMALS)).send();
    const creditInfo = await creditManager.getCreditInfo(config.Beneficiary1).call();
    console.log(`150 USDD repaid. Credit Info is now ${creditInfo}`);
  });
  
  // it('should allow admin to withdraw 1 BTC', async function () {
  //   this.timeout(10000);
  
  //   console.log('Admin withdrawing 1 BTC');
  //   await creditManager.withdraw(config.BTCAddress, await toSun(1, BTC_DECIMALS)).send();
  //   await creditManager.updateGlobalMaxCreditLimit(config.BTCCTokenAddress).send();
  //   const globalCreditLimit = await creditManager.globalMaxCreditLimit().call();
  //   console.log(`1 BTC withdrawn by admin. Global credit is now ${globalCreditLimit.toString()}`);
  // });



  // Add additional tests for other functions here
});
