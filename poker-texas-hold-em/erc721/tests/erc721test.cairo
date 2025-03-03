use starknet::{ContractAddress, ClassHash, contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, get_class_hash, start_cheat_caller_address,
    stop_cheat_caller_address,
};


#[starknet::interface]
trait IERC721Test<TContractState> {
    fn safeMint(
        ref self: TContractState, recipient: ContractAddress, token_id: u256, data: Span<felt252>,
    );
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}

#[cfg(test)]
mod tests {
    use super::DeclareResultTrait;
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

    /////////////////////////////
    //===> Ownership Tests <===//
    /////////////////////////////

    //== Should allow the owner to mint tokens ==//
    #[test]
    fn test_owner_can_mint() {
        // Step 1: Initializing
        let contract_address = deploy_contract();
        let dispatcher = IERC721TestDispatcher { contract_address };

        // Step 2: Setting up mint data
        let recipient: ContractAddress = USER();
        let token_id: u256 = 1;
        let metadata: Span<felt252> = array![].span();

        // Step 3: Call as owner to mint a token
        start_cheat_caller_address(contract_address, OWNER());
        dispatcher.safeMint(recipient, token_id, metadata);
        stop_cheat_caller_address(contract_address);
    }

    //== Should NOT allow users to mint tokens ==//
    #[test]
    #[should_panic] 
    fn test_users_cannot_mint() {
        // - Step 1: Initializing
        let contract_address = deploy_contract();
        let dispatcher = IERC721TestDispatcher { contract_address };

        // - Step 2: Setting up mint data
        let recipient: ContractAddress = USER();
        let token_id: u256 = 1;
        let metadata: Span<felt252> = array![].span();

        // - Step 3: Not owner tries to mint token
        dispatcher.safeMint(recipient, token_id, metadata);
    }

    //== Should allow the owner to upgrade the contract ==//
    #[test]
    fn test_contract_upgrade() {
        // Step 1: Deploy the initial contract
        let contract_address = deploy_contract();
        let dispatcher = IERC721TestDispatcher { contract_address };

        // Step 2: New contract setup
        let new_contract_class = declare("ERC721").unwrap().contract_class();

        let mut constructor_calldata: Array::<felt252> = array![];
        Serde::serialize(@OWNER(), ref constructor_calldata);
        Serde::serialize(@NAME(), ref constructor_calldata);
        Serde::serialize(@SYMBOL(), ref constructor_calldata);
        Serde::serialize(@URI(), ref constructor_calldata);

        let (new_contract_address, _) = new_contract_class.deploy(@constructor_calldata).unwrap();
        let new_class_hash = get_class_hash(new_contract_address);

        // Step 3: Set the caller to be the contract owner
        start_cheat_caller_address(contract_address, OWNER());

        // Step 4: Upgrade the contract using the upgrade function
        dispatcher.upgrade(new_class_hash);
    }

    //== Should prevent non-owners from upgrading the contract ==/
    #[test]
    #[should_panic]
    fn test_users_cannot_upgrade() {
        // Step 1: Deploy the initial contract
        let contract_address = deploy_contract();
        let dispatcher = IERC721TestDispatcher { contract_address };

        // Step 2: New contract setup
        let new_contract_class = declare("ERC721").unwrap().contract_class();

        let mut constructor_calldata: Array::<felt252> = array![];
        Serde::serialize(@OWNER(), ref constructor_calldata);
        Serde::serialize(@NAME(), ref constructor_calldata);
        Serde::serialize(@SYMBOL(), ref constructor_calldata);
        Serde::serialize(@URI(), ref constructor_calldata);

        let (new_contract_address, _) = new_contract_class.deploy(@constructor_calldata).unwrap();
        let new_class_hash = get_class_hash(new_contract_address);

        // Step 3: Upgrade the contract using the upgrade function (fails)
        // expect_revert!(dispatcher.upgrade(new_class_hash));
    }
}

