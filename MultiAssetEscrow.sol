pragma solidity ^0.8.0;


/**
Copyright 2021 Open DeFi DAO


Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 * */

/**
 * @title ERC20 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev An escrow for multiple assets between two parties
 * When the contract is deployed, the deployer to set up an escrow for two parties' addresses
 * The escrow beigns in the Setup state in which only the deployer can specify new terms for each party
 * deployer calls setTermA() to add terms for partyA, and calls setTermB() to add terms for partyB
 * Once all terms are added (At least one per party), the deployer calls start(uint256 deadline_) in order to transition the 
 * escrow to the Initialized state and sets a time limit for both parties to deposit assets per their terms.
 * Then, if the blocktime exceeds the deadline_ the contract will transition to the Voided state when checkState() is called.
 * In the Voided state, both parties can withdraw any assets they deposited using withdrawA() and withdrawB() respectively.
 * If both parties fulfil their escrow terms, before the deadline_ is reached, the contract will transition to the Executed
 * state when checkState() is called.
 * In the Executed state, partyA will be able to withdraw the assets partyB deposited by calling withdrawA(), and conversely
 * partyB will be able to withdraw the assets partyA deposited by calling withdrawB()
 * 
 */
contract MultiAssetEscrow{
    

    struct Asset{
        address token;
        uint256 required;
        uint256 deposited;
        uint256 withdrawn;
    }
    
    enum State { Setup, Initialized, Voided, Executed } 
    
    address deployer;
    address partyA;
    address partyB;
    
    uint8 numTermsA;
    uint8 numTermsB;
    
    mapping (uint8 => Asset) public termsA;    
    mapping (uint8 => Asset) public termsB;
    
    uint256 deadline;
    
    State public state;

    constructor(address partyA_, address partyB_){
        numTermsA = 0;
        numTermsB = 0;
        partyA = partyA_;
        partyB = partyB_;
        deployer = msg.sender;
        state = State.Setup;
    }
    
    function setTermA(address asset, uint256 amount) public {
        require(state == State.Setup, "can only set terms in Setup state");
        require(msg.sender == deployer, "only deployer can set terms");
        termsA[numTermsA].token = asset;
        termsA[numTermsA].required = amount;
        numTermsA = numTermsA + 1;
    }
    
    function setTermB(address asset, uint256 amount) public {
        require(state == State.Setup, "can only set terms in Setup state");
        require(msg.sender == deployer, "only deployer can set terms");
        termsB[numTermsB].token = asset;
        termsB[numTermsB].required = amount;
        numTermsB = numTermsB + 1;
    }
    
    function start(uint256 deadline_) public {
        require(state == State.Setup, "can only start in Setup state");
        require(msg.sender == deployer, "only deployer can start");
        require(deadline_ > block.timestamp, "Deadline must be in the future");
        require(numTermsA > 0 && numTermsB > 0, "Party cannot have empty terms");
        deadline = deadline_;
        state = State.Initialized;

    }
    
    
    function checkState() internal returns (State){
        if(state == State.Initialized){
            if(block.timestamp > deadline){
                state = State.Voided;
            } else if(termsMet()){
                state = State.Executed;
            }
        }
        return state;
    }
    
    function termsMet() public view returns (bool){
        return termsMetA() && termsMetB();
    }
    
    function termsMetA() public view returns (bool){
        for(uint8 i = 0; i < numTermsA; i=i+1){
            if(termsA[i].deposited < termsA[i].required){
                return false;
            }
        }
        return true;
    }
    
    function termsMetB() public view returns (bool){
        for(uint8 i = 0; i < numTermsB; i=i+1){
            if(termsB[i].deposited < termsB[i].required){
                return false;
            }
        }
        return true;
    }
    
    function depositA(uint8 term) public {
        require(msg.sender == partyA, "only party A may deposit");
        require(checkState() == State.Initialized, "Invalid State for Deposit");
        require(term < numTermsA, "Invalid Term");
        require(termsA[term].deposited == 0, "already deposited for this term");
        IERC20 token = IERC20(termsA[term].token);
        bool success = token.transferFrom(partyA, address(this), termsA[term].required);
        if(success){
            termsA[term].deposited = termsA[term].required;
        }
    }
    
    function depositB(uint8 term) public {
        require(msg.sender == partyB, "only party B may deposit");
        require(checkState() == State.Initialized, "Invalid State for Deposit");
        require(term < numTermsB, "Invalid Term");
        require(termsB[term].deposited == 0, "already deposited for this term");
        IERC20 token = IERC20(termsB[term].token);
        bool success = token.transferFrom(partyB, address(this), termsB[term].required);
        if(success){
            termsB[term].deposited = termsB[term].required;
        }
    }
    
    function withdrawA(uint8 term) public {
        checkState();
        if(state == State.Voided){
            require(term < numTermsA, "invalid term");
            IERC20 token = IERC20(termsA[term].token);
            require(termsA[term].withdrawn == 0, "already withdrawn");
            termsA[term].withdrawn = termsA[term].deposited;
            bool success = token.transfer(partyA, termsA[term].deposited);
            if(!success){
                revert("transfer failed");
            }
        } else if (state == State.Executed){
            require(term < numTermsB, "invalid term");
            IERC20 token = IERC20(termsB[term].token);
            require(termsB[term].withdrawn == 0, "already withdrawn");
            termsB[term].withdrawn = termsB[term].deposited;
            bool success = token.transfer(partyA, termsB[term].deposited);
            if(!success){
                revert("transfer failed");
            }            
        } else {
            revert("invalid withdrawal state");
        }
    }
    
    function withdrawB(uint8 term) public {
        checkState();
        if(state == State.Voided){
            require(term < numTermsB, "invalid term");
            IERC20 token = IERC20(termsB[term].token);
            require(termsB[term].withdrawn == 0, "already withdrawn");
            termsB[term].withdrawn = termsB[term].deposited;
            bool success = token.transfer(partyB, termsB[term].deposited);
            if(!success){
                revert("transfer failed");
            }
        } else if (state == State.Executed){
            require(term < numTermsA, "invalid term");
            IERC20 token = IERC20(termsA[term].token);
            require(termsA[term].withdrawn == 0, "already withdrawn");
            termsA[term].withdrawn = termsA[term].deposited;
            bool success = token.transfer(partyB, termsA[term].deposited);
            if(!success){
                revert("transfer failed");
            }            
        } else {
            revert("invalid withdrawal state");
        }
    }

}