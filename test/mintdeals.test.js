import TronWeb from 'tronweb';
import { expect } from 'chai';
// import { config } from './nile-config.js';
import { config } from './mainnet-config.js';
import 'dotenv/config';

const tronWeb = new TronWeb({
  fullHost: "https://api.trongrid.io",
  privateKey: process.env.PRIVATE_KEY_MAINNET,
});

const USDD_DECIMALS = 18;
const USDT_DECIMALS = 6;
const BTC_DECIMALS = 8;

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
    // this.timeout(10000);
    
    // console.log('Approving USDD for CreditFacility');
    // await USDDAddress.approve(config.CreditFacilityAddress,  await toSun(500, USDD_DECIMALS)).send();
    // console.log('USDD approved');

    // console.log('Approving USDT for CreditFacility');
    // await USDTAddress.approve(config.CreditFacilityAddress, await toSun(500, USDT_DECIMALS)).send();
    // console.log('USDT approved');

    // console.log('Approving BTC for CreditFacility');
    // await BTCAddress.approve(config.CreditFacilityAddress, await toSun(1, BTC_DECIMALS)).send();
    // console.log('BTC approved');

    // console.log('Approving USDD for CreditManager');
    // await USDDAddress.approve(config.CreditManagerAddress, await toSun(1000, USDD_DECIMALS)).send();
    // console.log('USDD approved for CreditManager');

    // console.log('Approving USDT for CreditManager');
    // await USDTAddress.approve(config.CreditManagerAddress, await toSun(1000, USDT_DECIMALS)).send();
    // console.log('USDT approved for CreditManager');

    // console.log('Approving BTC for CreditManager');
    // await BTCAddress.approve(config.CreditManagerAddress, await toSun(1, BTC_DECIMALS)).send();
    // console.log('BTC approved for CreditManager');

    // console.log('Approving USDD for ClubDealRegistry');
    // await USDDAddress.approve(config.ClubDealRegistryAddress, await toSun(1000, USDD_DECIMALS)).send();
    // console.log('USDD approved for ClubDealRegistry');
    
    // console.log('Approving USDT for ClubDealRegistry');
    // await USDTAddress.approve(config.ClubDealRegistryAddress, await toSun(1000, USDT_DECIMALS)).send();
    // console.log('USDT approved for ClubDealRegistry');
  });

  it('should add cToken info for USDD, USDT, BTC', async function () {
    // this.timeout(10000);

    // console.log('Adding USDD cToken');
    // await creditFacility.addCToken(config.USDDCTokenAddress, config.USDDAddress, true, config.USDDOracle).send();
    // console.log('USDD cToken added');

    // console.log('Adding USDT cToken');
    // await creditFacility.addCToken(config.USDTCTokenAddress, config.USDTAddress, true, config.USDTOracle).send();
    // console.log('USDT cToken added');

    // console.log('Adding BTC cToken');
    // await creditFacility.addCToken(config.BTCCTokenAddress, config.BTCAddress, false, config.BTCOracle).send();
    // console.log('BTC cToken added');
  });

  it('should supply assets and perform borrow/repay operations', async function() {
    // this.timeout(10000);

    // console.log('Supplying USDD');
    // await creditFacility.supplyAsset(config.USDDCTokenAddress, await toSun(1, USDD_DECIMALS), config.Beneficiary1).send();
    // console.log('USDD supplied');

    // console.log('Supplying USDT');
    // await creditFacility.supplyAsset(config.USDTCTokenAddress, await toSun(5, USDT_DECIMALS), config.Beneficiary1).send();
    // console.log('USDT supplied');

    // console.log('Supplying BTC');
    // await creditFacility.supplyAsset(config.BTCCTokenAddress, await toSun(1, BTC_DECIMALS), config.Beneficiary1).send();
    // console.log('BTC supplied');

    // console.log('Supplying USDD to Credit Manager');
    // await creditManager.supply(config.USDDAddress, await toSun(10, USDD_DECIMALS)).send();
    // console.log('USDD supplied to Credit Manager');

    // console.log('Supplying USDT to Credit Manager');
    // await creditManager.supply(config.USDTAddress, await toSun(10, USDT_DECIMALS)).send();
    // console.log('USDT supplied to Credit Manager');

    // console.log('Supplying BTC to Credit Manager');
    // await creditManager.supply(config.BTCAddress, await toSun(1, BTC_DECIMALS)).send();
    // console.log('BTC supplied to Credit Manager');

    // // Enable multiple cTokens as collateral
    // console.log('Enabling multiple assets as collateral');
    // await creditFacility.enableAsCollateral([
    //     config.USDDCTokenAddress, 
    //     config.USDTCTokenAddress, 
    //     config.BTCCTokenAddress
    // ]).send();
    // console.log('Assets enabled as collateral: USDD, USDT, BTC');


    // console.log('Borrowing USDD');
    // await creditFacility.borrow(config.USDDCTokenAddress, await toSun(5, USDD_DECIMALS)).send();
    // console.log('USDD borrowed');

    // console.log('Borrowing USDT');
    // await creditFacility.borrow(config.USDTCTokenAddress, await toSun(1, USDT_DECIMALS)).send();
    // console.log('USDT borrowed');

    // console.log('Repaying USDD borrow');
    // await creditFacility.repayBorrow(config.USDDCTokenAddress, await toSun(2, USDD_DECIMALS), config.Beneficiary1).send();
    // console.log('USDD borrow repaid');

    // console.log('Repaying USDT borrow');
    // await creditFacility.repayBorrow(config.USDTCTokenAddress, await toSun(1, USDT_DECIMALS), config.Beneficiary1).send();
    // console.log('USDT borrow repaid');

  });

  //ClubDealRegistry

  it('should set the ClubDealRegistry as admin on MintDealsNFT and CreditManager', async function () {
    // this.timeout(10000);
  
    // console.log(`Setting ClubDealRegistry as admin on CreditManager)`);
    // await creditManager.setAdmin(config.ClubDealRegistryAddress).send();
    // console.log('Admin set successfully.');  
    
    // console.log(`Setting ClubDealRegistry as admin on MintDealsNFT)`);
    // await mintDealsNFT.setAdmin(config.ClubDealRegistryAddress).send();
    // console.log('Admin set successfully.');
  });
  

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


  it('should create 2 Deals', async function () {
    // this.timeout(10000);
  
    // // Now create deals for each club

    // // Create a deal in club 1
    // console.log('Creating deal in club 0');
    // await clubDealRegistry.createDeal(
    //   0, // Club ID 1
    //   1000, // Max supply of the deal
    //   1758188985, // Expiry 18/9/2025
    //   "ipfs://deal-metadata-1", // Metadata URI for deal 1
    //   5 // Max mints per member
    // ).send();
    // console.log('Deal created successfully.');

    // // Create a deal in club 2
    // console.log('Creating deal in club 1');
    // await clubDealRegistry.createDeal(
    //   1, // Club ID 2
    //   500, // Max supply of the deal
    //   1758188985, // Expiry 18/9/2025
    //   "ipfs://deal-metadata-2", // Metadata URI for deal 2
    //   3 // Max mints per member
    // ).send();
    // console.log('Deal created successfully.');
  });

  it('should add a member to the club using USDD  and USDT as the payment tokens', async function () {
    // this.timeout(10000);
  
    // const memberAddress = 'TR5iq6xAxDvPXGm6bY7TzQX1MWmxhuXss5'; // Member's Tron address
  
    // console.log(`Adding member ${memberAddress} to club with USDD as payment token`);
    // await clubDealRegistry.addClubMember(
    //   0,    // ClubId
    //   memberAddress,         // Member address
    //   config.USDDAddress   // Payment token is USDD
    // ).send();
    // console.log('Member added successfully with USDD.');

    // console.log(`Adding member ${memberAddress} to club with USDD as payment token`);
    // await clubDealRegistry.addClubMember(
    //   1,    // ClubId
    //   memberAddress,         // Member address
    //   config.USDDAddress   // Payment token is USDD
    // ).send();
    // console.log('Member added successfully with USDD.');

  });
  
  
  //CreditManager
  it('should execute score steps (borrow 4 + repay 6)', async function () {
    // this.timeout(10000);
    
    // console.log('Executing ScoreSteps (Borrow 6, Repay 4)');
    // await creditManager.setScoreSteps(6, 4).send();
    // console.log('ScoreSteps executed (borrow 6 + repay 4)');
  });
  
  it('should supply BTC with beneficiary as creditManagerAddress', async function () {
    // this.timeout(10000);
  
    // console.log('Supplying 1 BTC');
    // await creditFacility.supplyAsset(config.BTCCTokenAddress, await toSun(1, BTC_DECIMALS), config.CreditManagerAddress).send();
    // console.log('1 BTC supplied to CreditFacility on behalf of CreditManagerAddress');
  });
  
  it('should update global max credit limit for BTC cToken', async function () {
    // this.timeout(10000);
  
    // console.log('Updating Global Max Credit Limit for BTC cToken');
    // await creditManager.updateGlobalMaxCreditLimit(config.BTCCTokenAddress).send();
    // const globalCreditLimit = await creditManager.globalMaxCreditLimit().call();
    // console.log(`Global Max Credit Limit for BTC updated to ${globalCreditLimit.toString()}`);
  });
  
  it('should borrow 20 USDD + 20 USDT from CreditManager', async function () {
    // this.timeout(10000);
  
    // console.log('Borrowing 20 USDD');
    // await creditManager.borrow(config.USDDAddress, await toSun(20, USDD_DECIMALS)).send();
    // const creditInfo1 = await creditManager.getCreditInfo(config.Beneficiary1).call();
    // console.log(`20 USDD borrowed - Credit Info is now ${creditInfo1}`);  
    
    // console.log('Borrowing 20 USDT');
    // await creditManager.borrow(config.USDTAddress, await toSun(20, USDT_DECIMALS)).send();
    // const creditInfo2 = await creditManager.getCreditInfo(config.Beneficiary1).call();
    // console.log(`20 USDT borrowed - Credit Info is now ${creditInfo2}`);

  });
  
  it('should repay USDT to CreditManager', async function () {
    // this.timeout(10000);
  
    // console.log('Repaying USDT');
    // await creditManager.repay(config.USDTAddress, await toSun(20, USDT_DECIMALS)).send();
    // const creditInfo = await creditManager.getCreditInfo(config.Beneficiary1).call();
    // console.log(`USDT repaid. Credit Info is now ${creditInfo}`);
  });
  
  it('should allow admin to withdraw 1 BTC', async function () {
  //   this.timeout(10000);
  
    // console.log('Admin withdrawing 1 BTC');
    // await creditManager.withdraw(config.BTCAddress, await toSun(1, BTC_DECIMALS)).send();
    // await creditManager.updateGlobalMaxCreditLimit(config.BTCCTokenAddress).send();
    // const globalCreditLimit = await creditManager.globalMaxCreditLimit().call();
    // console.log(`1 BTC withdrawn by admin. Global credit is now ${globalCreditLimit.toString()}`);
  });



  // Add additional tests for other functions here
});
