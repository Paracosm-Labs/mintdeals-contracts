MintDeals was built on the Tron blockchain, leveraging smart contracts to automate credit management and deal creation. We integrated with JustLendDAO to enable the shared credit facility and used Wink price oracle for fetching the value of BTC. The core contract components include:

MintDealsNFT: For minting and redemption of deals. Integrates with the ClubDealRegistry.

ClubDealRegistry: For creating and managing clubs, deals and splitting of received payments to Credit Facility and Credit Manager.

CreditManager: A contract account integrated with the CreditFacility, managing BTC, shared credit access, handles repayments and manages credit scoring that affects club owners' borrowing capacity.

CreditFacility: Manages individual credit access and collective funds as sub accounts and integrates directly into JustLendDAO for accessing supplying, lending, borrowing, repayment and yield claiming capabilities.

NextJS Frontend Repo: https://github.com/Paracosm-Labs/mint
