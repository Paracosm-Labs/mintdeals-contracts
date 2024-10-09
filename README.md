# About
MintDeals enables businesses to create blockchain-based clubs where they can offer exclusive and tokenizable deals to their members. Users pay a fee in stablecoin to join these clubs in order to mint and enjoy the deals. Behind the scenes, a DeFi-powered credit facility provides businesses with access to credit loans they need to grow and thrive. The credit facility funds are accumulated through the various membership payments made or earned through the platform and integrates with JustLendDAO for collateralized borrowing and liquidity management. Business' onchain activities help them build a credit score which is used as a metric to increase their borrowing capacity within the credit facility.

# Deployed Contracts
MintDeals was built on the Tron blockchain, leveraging smart contracts to automate credit management and deal creation. We integrated with JustLendDAO to enable the shared credit facility and used Wink price oracle for fetching the value of BTC. The core contract components include:

### MintDealsNFT: 
For minting and redemption of deals. Integrates with the ClubDealRegistry.

https://nile.tronscan.org/#/contract/TDx2X2RUTsoejVRbD1TqUEB8wr1D8ovCj2

### ClubDealRegistry: 
For creating and managing clubs, deals and splitting of received payments to Credit Facility and Credit Manager.

https://nile.tronscan.org/#/contract/TCWSSre2S5MfD4zkL5dAiZ5AVVhDALcHr5

### CreditManager: 
A contract account integrated with the CreditFacility, managing BTC, shared credit access, handles repayments and manages credit scoring that affects club owners' borrowing capacity.

https://nile.tronscan.org/#/contract/TLjtr3FWcXRW48p4Kv2UP1offUPt95bk9H

### CreditFacility: 
Manages individual credit access and collective funds as sub accounts and integrates directly into JustLendDAO for accessing supplying, lending, borrowing, repayment and yield claiming capabilities.

https://nile.tronscan.org/#/contract/TR5p4aky1nfWPS915EsYP5SDiFZfi5ZqcF

# Links:
Frontend on Vercel [Nile Tesnet]: https://mintdeals.vercel.app

Frontend Repo: https://github.com/Paracosm-Labs/mint

Docs: https://paracosmlabs.gitbook.io/mintdeals

MintDeals on Devpost: https://devpost.com/software/mintdeals

MintDeals on TronDAO Forum: https://forum.trondao.org/t/mintdeals-transforming-club-memberships-and-deals-with-defi-driven-credit-access/
