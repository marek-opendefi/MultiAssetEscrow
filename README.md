# MultiAssetEscrow
An escrow for multiple assets between two parties

Allows a deployer to set up an escrow for two parties' addresses
The escrow beigns in the Setup state in which only the deployer can specify new terms for each party
The deployer calls setTermA() to add terms for partyA, and calls setTermB() to add terms for partyB

Once all terms are added (At least one per party), the deployer calls start(uint256 deadline_) in order to transition the 
escrow to the Initialized state and sets a time limit for both parties to deposit assets per their terms.

Then, if the blocktime exceeds the deadline_ the contract will transition to the Voided state when checkState() is called.
In the Voided state, both parties can withdraw any assets they deposited using depositA and depositB respectively.

If both parties fulfil their escrow terms, before the deadline_ is reached, the contract will transition to the Executed
state when checkState() is called. 
In the Executed state, partyA will be able to withdraw the assets partyB deposited by calling withdrawA(), 
and conversely partyB will be able to withdraw the assets partyA deposited by calling withdrawB()
