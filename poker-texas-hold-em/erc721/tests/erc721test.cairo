use starknet::{ContractAddress, ClassHash, contract_address_const};
use core::starknet::syscalls;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};


#[starknet::interface]
trait IERC721Test<TContractState> {
    fn safeMint(
        ref self: TContractState,
        recipient: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    );
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn owner_of(ref self: TContractState, token_id: u256) -> ContractAddress;
}

#[cfg(test)]
mod tests {
    use super::DeclareResultTrait;
use super::IERC721TestDispatcherTrait;
    use super::*;

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

    fn deploy_contract() -> (ContractAddress, IERC721TestDispatcher) {
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

        let dispatcher = IERC721TestDispatcher { contract_address };

        // Step 4: Return contract address
        (contract_address, dispatcher)
    }

    //////////////////////////////////
    //===> Setup & Initializing <===//
    //////////////////////////////////

    //== Should deploy the contract with correct initial values ==//
    #[test]
    // #[ignore]
    fn test_constructor_assigns_initial_values_correctly() {
        // Step 1: Deploy contract
        let (contract, _) = deploy_contract();

        // Step 2: Checking Owner, Name, Symbol and URI are set correctly
        let mut call_data: Array<felt252> = array![];

        // Checking Owner set correctly
        let mut res = syscalls::call_contract_syscall(
            contract, selector!("owner"), call_data.span(),
        )
            .unwrap();
        let stored_owner: ContractAddress = Serde::<ContractAddress>::deserialize(ref res).unwrap();
        assert!(stored_owner == OWNER(), "Owner mismatch");

        // Checking Name set correctly
        let mut res = syscalls::call_contract_syscall(
            contract, selector!("token_name"), call_data.span(),
        )
            .unwrap();
        let stored_name: ByteArray = Serde::<ByteArray>::deserialize(ref res).unwrap();
        assert!(stored_name == NAME(), "Name mismatch");

        // Checking Symbol set correctly
        let mut res = syscalls::call_contract_syscall(
            contract, selector!("token_symbol"), call_data.span(),
        )
            .unwrap();
        let stored_symbol: ByteArray = Serde::<ByteArray>::deserialize(ref res).unwrap();
        assert!(stored_symbol == SYMBOL(), "Symbol mismatch");

        // Checking URI set correctly
        let mut res = syscalls::call_contract_syscall(
            contract, selector!("token_uri"), call_data.span(),
        )
            .unwrap();
        let stored_uri: ByteArray = Serde::<ByteArray>::deserialize(ref res)
            .unwrap(); // FAILS HERE BECAUSE OF THE UNWRAP FAIL
        assert!(stored_uri == URI(), "URI mismatch");
    }

    #[test]
    #[should_panic]
    #[ignore]
    fn test_fails_second_initialization_call() {
        // Step 1: Deploy the contract
        let (contract, _) = deploy_contract();

        // Step 2: Attempt to call the constructor again (this should fail)
        let mut constructor_calldata: Array::<felt252> = array![];
        Serde::serialize(@OWNER(), ref constructor_calldata);
        Serde::serialize(@NAME(), ref constructor_calldata);
        Serde::serialize(@SYMBOL(), ref constructor_calldata);
        Serde::serialize(@URI(), ref constructor_calldata);

        let res = syscalls::call_contract_syscall(
            contract, selector!("constructor"), constructor_calldata.span(),
        );

        assert!(res.is_err(), "Contract allowed second initialization, which should not happen");
    }

    /////////////////////////////
    //===> Ownership Tests <===//
    /////////////////////////////

    //== Should allow the owner to mint tokens ==//
    #[test]
    #[ignore]
    fn test_owner_can_mint() {
        // - Step 1: Initializing
        let owner = OWNER();
        let (contract, dispatcher) = deploy_contract();
        
        // - Step 2: Setting up mint data
        let recipient: ContractAddress = USER();
        let token_id: u256 = 1;
        let metadata: Span<felt252> = array![].span();

        start_cheat_caller_address(contract, owner);
        dispatcher.safeMint(recipient, token_id, metadata);
        stop_cheat_caller_address(contract);

        assert!(dispatcher.owner_of(token_id) == recipient, "wrong token owner");
    }
    //== Should NOT allow users to mint tokens ==//
    #[test]
    #[should_panic]
    fn test_users_cannot_mint() { // ✅
        // - Step 1: Initializing
        let user = USER();
        let (_, dispatcher) = deploy_contract();

        // - Step 2: Setting up mint data
        let recipient: ContractAddress = user;
        let token_id: u256 = 1;
        let metadata: Span<felt252> = array![].span();

        // - Step 3: Not owner tries to mint token
        dispatcher.safeMint(recipient, token_id, metadata);
    }

    //== Should allow the owner to upgrade the contract ==//
    #[test]
    #[should_panic]
    #[ignore]
    fn test_owner_can_upgrade() {
        // - Step 1: Initializing
        let owner = OWNER();
        let (contract, dispatcher) = deploy_contract();

        // Step 2: Declare a new contract class (simulating an upgrade)
        let new_contract = declare("ERC721_NEW").unwrap().contract_class();

        // Step 2: Prepare constructor calldata
        let mut constructor_calldata: Array::<felt252> = array![];
        Serde::serialize(@OWNER(), ref constructor_calldata);
        Serde::serialize(@NAME(), ref constructor_calldata);
        Serde::serialize(@SYMBOL(), ref constructor_calldata);
        Serde::serialize(@URI(), ref constructor_calldata);

        // Step 3: Deploy the contract with constructor calldata
        // let new_class_hash: ClassHash = new_contract.

        // - Step 3: Calling the upgrade function
        // start_cheat_caller_address(contract, owner);
        // dispatcher.upgrade(new_class);
        // stop_cheat_caller_address(contract);
    }

    //== Should prevent non-owners from upgrading the contract ==/

    fn test_users_cannot_upgrade() {
        // - Step 1: Initializing
        let (contract, dispatcher) = deploy_contract(); 

        // Step 2: Declare a new contract class (simulating an upgrade)
        let new_contract = declare("ERC721_NEW").unwrap().contract_class();

        // Step 2: Prepare constructor calldata
        let mut constructor_calldata: Array::<felt252> = array![];
        Serde::serialize(@OWNER(), ref constructor_calldata);
        Serde::serialize(@NAME(), ref constructor_calldata);
        Serde::serialize(@SYMBOL(), ref constructor_calldata);
        Serde::serialize(@URI(), ref constructor_calldata);

        let (contract_address, _) = new_contract.deploy(@constructor_calldata).unwrap();

        // let new_class_hash: ClassHash = contract_address.clas

        // dispatcher.upgrade();
    }
}


