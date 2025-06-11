use starknet::{ContractAddress, contract_address_const, ClassHash};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, get_class_hash, start_cheat_caller_address,
    stop_cheat_caller_address, spy_events, EventSpyTrait, EventSpyAssertionsTrait,
};
use openzeppelin::upgrades::interface::{IUpgradeableDispatcherTrait, IUpgradeableDispatcher};
use openzeppelin::token::erc721::interface::{
    ERC721ABIDispatcherTrait as NFTDispatcherTrait, ERC721ABIDispatcher as NFTDispatcher,
};
use tokens::erc721::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::token::erc721::ERC721Component::{Event, Transfer, Approval};

#[cfg(test)]
mod tests {
    use super::*;

    /////////////////////
    //===> Helpers <===//
    /////////////////////

    //== Owner Role ==//
    fn OWNER() -> ContractAddress {
        let owner: ContractAddress = contract_address_const::<'owner'>();

        owner
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
        let user: ContractAddress = contract_address_const::<'USER'>();

        user
    }
    fn NEWUSER() -> ContractAddress {
        let new_user: ContractAddress = contract_address_const::<'NEW_USER'>();

        new_user
    }

    fn zero() -> ContractAddress {
        contract_address_const::<0>()
    }

    //////////////////////////////////
    //===> Setup & Initializing <===//
    //////////////////////////////////

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

    //== Helper function to declare the contract class hash for upgrades ==//
    fn declare_upgrade_class() -> ClassHash {
        let new_contract_class = declare("ERC721").unwrap().contract_class();

        let mut constructor_calldata: Array::<felt252> = array![];
        Serde::serialize(@OWNER(), ref constructor_calldata);
        Serde::serialize(@NAME(), ref constructor_calldata);
        Serde::serialize(@SYMBOL(), ref constructor_calldata);
        Serde::serialize(@URI(), ref constructor_calldata);

        let (new_contract_address, _) = new_contract_class.deploy(@constructor_calldata).unwrap();
        get_class_hash(new_contract_address)
    }

    // Helper function to declare and deploy the receiver mock
    fn setup_receiver() -> ContractAddress {
        let receiver_class = declare("DualCaseERC721ReceiverMock").unwrap().contract_class();
        let (contract_address, _) = receiver_class.deploy(@array![]).unwrap();
        contract_address
    }

    /////////////////////////////
    //===> Comprehensive Tests <===//
    /////////////////////////////

    #[test]
    fn test_constructor_initial_state() {
        // Step 1: Deploy the contract
        let contract_address = deploy_contract();
        let dispatcher = NFTDispatcher { contract_address };

        // Step 2: Check initial state
        assert(dispatcher.name() == NAME(), 'Wrong name');
        assert(dispatcher.symbol() == SYMBOL(), 'Wrong symbol');
        assert(dispatcher.balance_of(OWNER()) == 0, 'Wrong initial balance');
    }

    //== Should allow the owner to mint tokens ==//
    #[test]
    fn test_owner_can_mint() {
        // Step 1: Initializing
        let contract_address = deploy_contract();
        let dispatcher = NFTDispatcher { contract_address };
        let tokens_dispatcher = IERC721Dispatcher {
            contract_address,
        }; // Using the interface in implemented ERC721 for minting
        let mut spy = spy_events();

        // Step 2: Setting up mint data
        let recipient: ContractAddress = USER();
        let token_id: u256 = 1;

        // Step 3: Call as owner to mint a token
        start_cheat_caller_address(contract_address, OWNER());
        tokens_dispatcher.mint(recipient, token_id);
        stop_cheat_caller_address(contract_address);

        // Step 4: Check ownership and balance
        assert(dispatcher.owner_of(token_id) == recipient, 'Wrong owner');
        assert(dispatcher.balance_of(recipient) == 1, 'Wrong balance');

        // Step 5: Check token URI
        let expected = format!("{}{}", URI(), token_id);
        assert(dispatcher.token_uri(token_id) == expected, 'Owner token URI mismatch');

        // Step 8: Get all emitted events
        let events = spy.get_events();
        assert(events.events.len() == 1, 'Incorrect number of events');

        // Step 9: Verify expected event sequence
        let expected_events = array![
            // Minting creates a Transfer event
            (
                contract_address,
                Event::Transfer(Transfer { from: zero(), to: recipient, token_id: token_id }),
            ),
        ];

        spy.assert_emitted(@expected_events);
    }

    #[test]
    fn test_owner_can_mint_to_receiver() {
        // Step 1: Initializing
        let contract_address = deploy_contract();
        let dispatcher = NFTDispatcher { contract_address };
        let tokens_dispatcher = IERC721Dispatcher {
            contract_address,
        }; // Using the interface in implemented ERC721 for minting

        // Step 2: Setting up mint data
        let recipient: ContractAddress = setup_receiver();
        let token_id: u256 = 1;

        // Step 3: Call as owner to mint a token
        start_cheat_caller_address(contract_address, OWNER());
        tokens_dispatcher.mint(recipient, token_id);
        stop_cheat_caller_address(contract_address);

        // Step 4: Verify ownership and balance
        assert(dispatcher.owner_of(token_id) == recipient, 'Wrong owner');
        assert(dispatcher.balance_of(recipient) == 1, 'Wrong balance');
    }

    #[test]
    fn test_approved_can_transfer_from() {
        // Step 1: Initializing
        let contract_address = deploy_contract();
        let dispatcher = NFTDispatcher { contract_address };
        let tokens_dispatcher = IERC721Dispatcher {
            contract_address,
        }; // Using the interface in implemented ERC721 for minting
        let mut spy = spy_events();

        // Step 2: Setting up mint data
        let recipient: ContractAddress = USER();
        let token_id: u256 = 1;

        // Step 3: Call as owner to mint a token
        start_cheat_caller_address(contract_address, OWNER());
        tokens_dispatcher.mint(recipient, token_id);
        stop_cheat_caller_address(contract_address);

        // Step 4: Approve the new/non-owner to transfer
        let new_owner: ContractAddress = NEWUSER();
        start_cheat_caller_address(contract_address, recipient);
        dispatcher.approve(new_owner, token_id);
        stop_cheat_caller_address(contract_address);

        // Step 5: Transfer the token
        start_cheat_caller_address(contract_address, new_owner);
        dispatcher.transfer_from(recipient, new_owner, token_id);
        stop_cheat_caller_address(contract_address);

        // Step 6: Verify state changes
        assert(dispatcher.owner_of(token_id) == new_owner, 'Wrong owner after transfer');
        assert(dispatcher.balance_of(new_owner) == 1, 'Wrong balance of new owner');
        assert(dispatcher.balance_of(recipient) == 0, 'Wrong balance of previous owner');

        // Step 7: Get all emitted events
        let events = spy.get_events();
        assert(events.events.len() == 3, 'Incorrect number of events');

        // Step 8: Verify expected event sequence
        let expected_events = array![
            // Minting creates a Transfer event
            (
                contract_address,
                Event::Transfer(Transfer { from: zero(), to: recipient, token_id: token_id }),
            ),
            // Approval event
            (
                contract_address,
                Event::Approval(
                    Approval { owner: recipient, approved: new_owner, token_id: token_id },
                ),
            ),
            // Transfer event
            (
                contract_address,
                Event::Transfer(Transfer { from: recipient, to: new_owner, token_id: token_id }),
            ),
        ];

        // Step 9: Assert all expected events were emitted
        spy.assert_emitted(@expected_events);
    }

    #[test]
    #[should_panic(expected: 'ERC721: unauthorized caller')]
    fn test_unapproved_cannot_transfer_token() {
        // Step 1: Initializing
        let contract_address = deploy_contract();
        let dispatcher = NFTDispatcher { contract_address };
        let tokens_dispatcher = IERC721Dispatcher {
            contract_address,
        }; // Using the interface in implemented ERC721 for minting

        // Step 2: Setting up mint data
        let recipient: ContractAddress = USER();
        let token_id: u256 = 1;

        // Step 3: Call as owner to mint a token
        start_cheat_caller_address(contract_address, OWNER());
        tokens_dispatcher.mint(recipient, token_id);
        stop_cheat_caller_address(contract_address);

        // Step 4: Attempt to transfer the token as non-owner without approval
        let new_owner: ContractAddress = NEWUSER();
        start_cheat_caller_address(contract_address, new_owner);
        dispatcher.transfer_from(OWNER(), new_owner, token_id);
    }

    #[test]
    #[should_panic(expected: 'ERC721: invalid token ID')]
    fn test_transfer_from_nonexistent_token() {
        // Step 1: Initializing
        let contract_address = deploy_contract();
        let dispatcher = NFTDispatcher { contract_address };

        let recipient: ContractAddress = USER();
        let invalid_token_id: u256 = 1; // Token is not minted yet

        // Step 2: Attempt to transfer an invalid token ID
        start_cheat_caller_address(contract_address, recipient);
        // Token owner can transfer to anyone without approval
        dispatcher.transfer_from(recipient, recipient, invalid_token_id);
    }

    #[test]
    #[should_panic(expected: 'ERC721: invalid receiver')]
    fn test_transfer_to_invalid_receiver() {
        // Step 1: Initializing
        let contract_address = deploy_contract();
        let dispatcher = NFTDispatcher { contract_address };
        let tokens_dispatcher = IERC721Dispatcher {
            contract_address,
        }; // Using the interface in implemented ERC721 for minting

        // Step 2: Setting up mint data
        let recipient: ContractAddress = USER();
        let token_id: u256 = 1;

        // Step 3: Call as owner to mint a token
        start_cheat_caller_address(contract_address, OWNER());
        tokens_dispatcher.mint(recipient, token_id);

        // Step 4: Attempt to transfer to an invalid/zero receiver
        // Token owner needs no approval to transfer
        let invalid_receiver: ContractAddress = zero();
        dispatcher.transfer_from(recipient, invalid_receiver, token_id);
    }


    //== Should NOT allow users to mint tokens ==//
    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_users_cannot_mint() {
        // - Step 1: Initializing
        let contract_address = deploy_contract();
        let tokens_dispatcher = IERC721Dispatcher {
            contract_address,
        }; // Using the interface in implemented ERC721 for minting

        // - Step 2: Setting up mint data
        let recipient: ContractAddress = USER();
        let token_id: u256 = 1;

        // - Step 3: Not owner tries to mint token
        tokens_dispatcher.mint(recipient, token_id);
    }

    //== Should allow the owner to upgrade the contract ==//
    #[test]
    fn test_contract_upgrade() {
        // Step 1: Deploy the initial contract
        let contract_address = deploy_contract();
        let dispatcher = IUpgradeableDispatcher { contract_address };
        let new_class_hash = declare_upgrade_class();

        // Step 2: Set the caller to be the contract owner
        start_cheat_caller_address(contract_address, OWNER());

        // Step 4: Upgrade the contract using the upgrade function
        dispatcher.upgrade(new_class_hash);
    }

    //== Should prevent non-owners from upgrading the contract ==/
    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_users_cannot_upgrade() {
        // Step 1: Deploy the initial contract
        let contract_address = deploy_contract();
        let dispatcher = IUpgradeableDispatcher { contract_address };
        let new_class_hash = declare_upgrade_class();

        // Step 3: Upgrade the contract using the upgrade function (fails)
        dispatcher.upgrade(new_class_hash);
    }
}
