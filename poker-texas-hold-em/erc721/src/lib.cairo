pub mod erc721;

use starknet::{ContractAddress, contract_address_const};
use core::starknet::syscalls;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

/////////////////////
//===> Helpers <===//
/////////////////////

//== Owner Role ==//
fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

//== NFT Name ==//
fn NAME() -> ByteArray {
    "Poker"
}

//== NFT Symbol ==//
fn SYMBOL() -> ByteArray {
    "PKR"
}

//== NFT URI ==//
fn URI() -> ByteArray {
    "https://poker.com/mock-uri"
}

//== User Role ==//
fn USER() -> ContractAddress {
    contract_address_const::<'USER'>()
}

fn deploy_contract() -> ContractAddress {
    // Step 1: Declare the contract
    let contract = declare("ERC721").unwrap().contract_class();

    // Step 2: Prepare constructor calldata
    let mut constructor_calldata: Array::<felt252> = array![];
    Serde::serialize(@OWNER(), ref constructor_calldata);
    Serde::serialize(@NAME(), ref constructor_calldata);
    Serde::serialize(@SYMBOL(), ref constructor_calldata);
    Serde::serialize(@URI(), ref constructor_calldata);

    // Step 3: Deploy the contract with constructor calldata
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    // Step 4: Return contract address
    contract_address
}

#[cfg(test)]
mod tests {
    use super::*;

    //////////////////////////////////
    //===> Setup & Initializing <===//
    //////////////////////////////////

    //== Should deploy the contract with correct initial values ==//
    #[test]
    fn test_constructor_assigns_initial_values_correctly() {
        // Step 1: Deploy contract
        let contract = deploy_contract();
        
        // Step 2: Checking Owner, Name, Symbol and URI are set correctly
        let mut call_data: Array<felt252> = array![];

        // Checking Owner set correctly
        let mut res = syscalls::call_contract_syscall(
            contract, selector!("owner"), call_data.span()
        ).unwrap();
        let stored_owner: ContractAddress = Serde::<ContractAddress>::deserialize(ref res).unwrap();
        assert!(stored_owner == OWNER(), "Owner mismatch");

        // Checking Name set correctly
        let mut res = syscalls::call_contract_syscall(
            contract, selector!("token_name"), call_data.span()
        ).unwrap();
        let stored_name: ByteArray = Serde::<ByteArray>::deserialize(ref res).unwrap();
        assert!(stored_name == NAME(), "Name mismatch");

        // Checking Symbol set correctly
        let mut res = syscalls::call_contract_syscall(
            contract, selector!("token_symbol"), call_data.span()
        ).unwrap();
        let stored_symbol: ByteArray = Serde::<ByteArray>::deserialize(ref res).unwrap();
        assert!(stored_symbol == SYMBOL(), "Symbol mismatch");

        // Checking URI set correctly
        let mut res = syscalls::call_contract_syscall(
            contract, selector!("token_uri"), call_data.span()
        ).unwrap();
        let stored_uri: ByteArray = Serde::<ByteArray>::deserialize(ref res).unwrap(); // FAILS HERE BECAUSE OF THE UNWRAP FAIL
        assert!(stored_uri == URI(), "URI mismatch"); 
    }

    #[test]
    #[should_panic]
    fn test_fails_second_initialization_call() {
        // Step 1: Deploy the contract
        let contract = deploy_contract();

        // Step 2: Attempt to call the constructor again (this should fail)
        let mut constructor_calldata: Array::<felt252> = array![];
        Serde::serialize(@OWNER(), ref constructor_calldata);
        Serde::serialize(@NAME(), ref constructor_calldata);
        Serde::serialize(@SYMBOL(), ref constructor_calldata);
        Serde::serialize(@URI(), ref constructor_calldata);

        let res = syscalls::call_contract_syscall(
            contract, selector!("constructor"), constructor_calldata.span()
        );

        assert!(res.is_err(), "Contract allowed second initialization, which should not happen");
    }

    /////////////////////////////
    //===> Ownership Tests <===//
    /////////////////////////////

    //== Should allow only the owner to mint tokens ==//
    #[test]
    fn test_only_owner_can_mint() {
        // - Step 1: Initializing

        // - Step 2: Owner mints token

        // - Step 3: Other user tries to mint and fails

    }
    // - The contract owner should be able to call safe_mint.
    // - Any other account should be rejected.
}


//== Should allow the owner to transfer ownership ==//
// - The owner should be able to transfer contract ownership.
// - The new owner should now have minting privileges.

//== Should prevent non-owners from upgrading the contract ==/
// - Ensure upgrade(new_class_hash) fails when a non-owner tries to execute it.

//////////////////////////////////////////////
//===> Minting & Token Management Tests <===//
//////////////////////////////////////////////

//== Should mint an ERC721 token successfully ==//
// - The owner mints a new token.
// - The recipient should now own the token.
// - The total supply should increase.

//== Should emit an event on minting ==//
// - Verify the ERC721Event::Minted event is emitted correctly.

//== Should prevent minting an already existing token ID ==//
// - Attempt to mint a token with an existing token_id should fail.

//////////////////////////////////
//===> Token Transfer Tests <===//
//////////////////////////////////

//== Should allow an owner to transfer their token ==//
// - The token owner should be able to transfer their token to another address.
// - The new owner should now own the token.
// - The old owner should no longer have ownership.

//== Should prevent unauthorized transfers ==//
// - Ensure that non-owners cannot transfer someone else’s token.
// - Ensure approval is required for a transfer.

//== Should emit an event on successful transfer ==//
// - Verify that ERC721Event::Transferred is emitted when a token is transferred.

//== Should allow approved operators to transfer tokens ==//
// - A token owner should be able to approve another account to transfer their token.
// - The approved operator should be able to transfer the token successfully.
// - Ensure that approval is required for transfers when the sender is not the owner.

//////////////////////////////////
//===> Upgradeability Tests <===//
//////////////////////////////////

// @note make sure there are no issues with upgradability hijacking

//== Should allow only the owner to upgrade the contract ==//
// - The contract owner should be able to call upgrade(new_class_hash).
// - Ensure upgrade succeeds only when called by the owner.

//== Should prevent non-owners from upgrading the contract ==/
// - Any non-owner should be rejected when calling upgrade(new_class_hash).

/////////////////////////////////////////
//===> Error Handling & Edge Cases <===//
/////////////////////////////////////////

//== Should fail to mint a token with an invalid recipient ==//
// - Ensure minting fails if the recipient address is invalid or zero.

//== Should fail to mint a token with an invalid ID ==//
// - Ensure minting fails if the token_id is invalid or already exists.

//== Should revert when querying ownership of a nonexistent token ==//
// - Ensure calling ownerOf(nonexistent_token_id) fails.
