//===> Imports <===// @note make sure I actually use all of this, if not delete
use starknet::test_utils::{deploy_contract, get_contract_address, get_account}; // Utilities for deploying and interacting with the contract in tests.
use starknet::contract_address::ContractAddress; // Used for handling contract addresses.
use starknet::syscalls::{call_contract, deploy, get_caller_address}; // Helps interact with deployed contracts in tests.
use openzeppelin::token::erc721::ERC721Component; // Includes ERC721 functionality for minting & ownership checks.
use openzeppelin::access::ownable::OwnableComponent; // Ensures only the owner can mint or upgrade the contract.
use openzeppelin::introspection::src5::SRC5Component; // Provides ERC721 standard compatibility.
use openzeppelin::upgrades::UpgradeableComponent; // Ensures upgradeability functionality works correctly.
use openzeppelin::test_utils::expect_revert; // Helper to test reverted transactions (expected failures).
use openzeppelin::test_utils::event_emitter::EventEmitter; // Used to check that expected events are emitted.
use core::integer::u256; // Required for handling token ID operations.
use core::array::Span; // Used to handle span data for token metadata.

//////////////////////////////////////////
//===> Helper Variables & Functions <===//
//////////////////////////////////////////

const OWNER: felt252 = selector!("OWNER");
const TOKEN_NAME: felt252 = selector!("POKER");
const TOKEN_SYMBOL: felt252 = selector!("PKR");
const TOKEN_URI: felt252 = selector!("ipfs://test_metadata");
let contract;

pub fn deploy_contract() {
    contract = deploy_contract(
        "ERC721", 
        (OWNER, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_URI)
    );
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
        // - Step 1: Ensure the contract is deployed successfully.
        deploy_contract();
        // - Step 2: Verify that owner, token_name, token_symbol, and token_uri are set correctly.
        let stored_owner: ContractAddress = contract.call("owner");
        assert_eq!(stored_owner, OWNER, "Owner mismatch");

        let stored_token_name: ByteArray = contract.call("erc721_token_name");
        assert_eq!(stored_token_name, TOKEN_NAME, "Token name mismatch");

        let stored_token_symbol: ByteArray = contract.call("erc721_token_symbol");
        assert_eq!(stored_token_symbol, TOKEN_SYMBOL, "Token symbol mismatch");

        let stored_token_uri: ByteArray = contract.call("erc721_token_uri");
        assert_eq!(stored_token_uri, TOKEN_URI, "Token URI mismatch");
    }

    //== Should fail initialization if called twice ==//
    #[test]
    fn test_fails_second_initialization_call() {
        // - Step 1: First initialization call (should pass)
        deploy_contract();
        // - Step 2: Second initialization call (should fail)
        expect_revert!(deploy_contract());
    }

    /////////////////////////////
    //===> Ownership Tests <===//
    /////////////////////////////

    //== Should allow only the owner to mint tokens ==//
    #[test]
    fn test_only_owner_can_mint() {
        // - Step 1: Initializing
        deploy_contract();
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