#[cfg(test)]
mod tests {
    use tokens::erc20::{ITokensDispatcher, ITokensDispatcherTrait};
    use starknet::{ContractAddress, contract_address_const, ClassHash};
    use openzeppelin::access::ownable::interface::{OwnableABIDispatcher, OwnableABIDispatcherTrait};
    use openzeppelin::token::erc20::interface::{
        IERC20MixinDispatcher as IERC20Dispatcher,
        IERC20MixinDispatcherTrait as IERC20DispatcherTrait,
    };
    use openzeppelin::upgrades::interface::{IUpgradeableDispatcherTrait, IUpgradeableDispatcher};
    use openzeppelin::token::erc20::ERC20Component::{Event, Transfer};
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent::{
        Event as UpgradeEvent, Upgraded,
    };
    use snforge_std::{
        declare, ContractClassTrait, DeclareResultTrait, get_class_hash, spy_events, EventSpyTrait,
        EventSpyAssertionsTrait, start_cheat_caller_address, stop_cheat_caller_address,
    };

    fn owner() -> ContractAddress {
        contract_address_const::<'owner'>()
    }
    fn alice() -> ContractAddress {
        contract_address_const::<'alice'>()
    }
    fn bob() -> ContractAddress {
        contract_address_const::<'bob'>()
    }
    fn zero() -> ContractAddress {
        contract_address_const::<0>()
    }

    const INITIAL_SUPPLY: u256 = 1_000_000_u256;
    const MINT_AMOUNT: u256 = 1000_u256;

    // ----    Helper Functions    ----

    fn setup() -> (
        IERC20Dispatcher, OwnableABIDispatcher, IUpgradeableDispatcher, ITokensDispatcher,
    ) {
        let contract_class = declare("ERC20").unwrap().contract_class();
        let owner = owner();
        let name: ByteArray = "TestToken";
        let symbol: ByteArray = "TTK";
        let supply = INITIAL_SUPPLY;

        let mut constructor_args: Array<felt252> = array![];
        owner.serialize(ref constructor_args);
        name.serialize(ref constructor_args);
        symbol.serialize(ref constructor_args);
        supply.serialize(ref constructor_args);

        let (contract_address, _) = contract_class.deploy(@constructor_args).unwrap();

        // Create dispatchers to interact with the deployed contract
        let tokens_erc20 = ITokensDispatcher { contract_address: contract_address };
        let erc20 = IERC20Dispatcher { contract_address: contract_address };
        let ownable = OwnableABIDispatcher { contract_address: contract_address };
        let upgradeable = IUpgradeableDispatcher { contract_address: contract_address };

        (erc20, ownable, upgradeable, tokens_erc20)
    }

    // Declare Contract Class and return the Class Hash
    fn declare_contract(name: ByteArray) -> ClassHash {
        let declare_result = declare(name);
        let declared_contract = declare_result.unwrap().contract_class();
        *declared_contract.class_hash
    }

    // ----    Comprehensive Tests for OpenZeppelin ERC20    ----

    #[test]
    fn test_constructor_initial_state() {
        let (erc20_dispatcher, ownable_dispatcher, _, _) = setup();

        // Verify initial state
        let total_supply = erc20_dispatcher.total_supply();
        let contract_owner = ownable_dispatcher.owner();

        assert(total_supply == INITIAL_SUPPLY, 'Total supply mismatch');
        assert(contract_owner == owner(), 'Contract owner mismatch');
        assert(erc20_dispatcher.name() == "TestToken", 'Wrong name');
        assert(erc20_dispatcher.symbol() == "TTK", 'Wrong symbol');
        assert(erc20_dispatcher.balanceOf(owner()) == INITIAL_SUPPLY, 'Owner balance mismatch');
    }

    #[test]
    fn test_mint_by_owner() {
        let initial_supply = INITIAL_SUPPLY;
        let owner = owner();
        let recipient = alice();
        let mint_amount = 500_u256;

        let (erc20_dispatcher, _, _, tokens_erc20_dispatcher) = setup();

        // Setup event spy
        let mut spy = spy_events();

        start_cheat_caller_address(tokens_erc20_dispatcher.contract_address, owner);

        // Use mint function from implemented ERC20 contract (ITokensDispatcher)
        tokens_erc20_dispatcher.mint(recipient, mint_amount);

        // Verify recipient balance increased
        let recipient_balance = erc20_dispatcher.balanceOf(recipient);
        assert(recipient_balance == mint_amount, 'Recipient balance incorrect');

        // Verify total supply increased
        let total_supply = erc20_dispatcher.totalSupply();
        assert(total_supply == initial_supply + mint_amount, 'Total supply incorrect');

        // Get emitted events
        let events = spy.get_events();
        assert!(events.events.len() == 1, "Minting Transfer event not emitted");

        // Verify Transfer event emission
        let expected_event = Event::Transfer(
            Transfer { from: zero(), to: recipient, value: mint_amount },
        );
        let expected_events = array![(tokens_erc20_dispatcher.contract_address, expected_event)];
        spy.assert_emitted(@expected_events);
    }

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_mint_by_non_owner_should_panic() {
        let non_owner = bob();
        let recipient = alice();
        let mint_amount = 500_u256;

        let (_, _, _, tokens_erc20_dispatcher) = setup();

        // Set caller address to non_owner
        start_cheat_caller_address(tokens_erc20_dispatcher.contract_address, non_owner);

        // Use mint function from implemented ERC20 contract (ITokensDispatcher)
        tokens_erc20_dispatcher.mint(recipient, mint_amount);
    }

    #[test]
    fn test_transfer_success() {
        let initial_supply = INITIAL_SUPPLY;
        let owner = owner();
        let recipient = alice();
        let transfer_amount = 500_u256;

        let (erc20_dispatcher, _, _, _) = setup();

        // Setup event spy
        let mut spy = spy_events();

        // Set caller address to owner
        start_cheat_caller_address(erc20_dispatcher.contract_address, owner);

        // Perform the transfer
        erc20_dispatcher.transfer(recipient, transfer_amount);

        // Verify balances
        let owner_balance = erc20_dispatcher.balanceOf(owner);
        let recipient_balance = erc20_dispatcher.balanceOf(recipient);

        assert!(
            owner_balance == initial_supply - transfer_amount, "Wrong owner balance after transfer",
        );
        assert!(recipient_balance == transfer_amount, "Wrong recipient balance after transfer");

        // Get emitted events
        let events = spy.get_events();
        assert(events.events.len() == 1, 'Tranfer event not emitted');

        // Verify Transfer event emission
        let expected_event = Event::Transfer(
            Transfer { from: owner, to: recipient, value: transfer_amount },
        );
        let expected_events = array![(erc20_dispatcher.contract_address, expected_event)];
        spy.assert_emitted(@expected_events);
    }

    #[test]
    #[should_panic(expected: 'ERC20: insufficient balance')]
    fn test_transfer_insufficient_balance_should_panic() {
        let non_owner = bob();
        let recipient = alice();
        let transfer_amount = 100_u256;

        let (erc20_dispatcher, _, _, _) = setup();

        // Set caller address to non-owner (with 0 balance)
        start_cheat_caller_address(erc20_dispatcher.contract_address, non_owner);

        // Attempt to transfer tokens
        erc20_dispatcher.transfer(recipient, transfer_amount);
    }

    #[test]
    fn test_upgrade_by_owner() {
        let (_, _, upgradeable_dispatcher, _) = setup();
        let new_class_hash = declare_contract("ERC721");
        let mut spy = spy_events();

        // Set caller address to owner
        start_cheat_caller_address(upgradeable_dispatcher.contract_address, owner());

        // Call the upgrade function as the owner
        upgradeable_dispatcher.upgrade(new_class_hash);

        stop_cheat_caller_address(upgradeable_dispatcher.contract_address);

        // Verify the upgrade was successful by checking the class hash
        let current_class_hash = get_class_hash(upgradeable_dispatcher.contract_address);
        assert(current_class_hash == new_class_hash, 'Contract upgrade failed');

        // Get emitted events
        let events = spy.get_events();
        assert(events.events.len() == 1, 'Upgrade event not emitted');
        // Verify upgrade event
        let expected_upgrade_event = UpgradeEvent::Upgraded(
            Upgraded { class_hash: new_class_hash },
        );

        // Assert that the event was emitted
        let expected_events = array![
            (upgradeable_dispatcher.contract_address, expected_upgrade_event),
        ];
        spy.assert_emitted(@expected_events);
    }

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_upgrade_by_non_owner_should_panic() {
        let (_, _, upgradeable_dispatcher, _) = setup();
        let new_class_hash = declare_contract("ERC721");

        // Set caller address to non-owner
        start_cheat_caller_address(upgradeable_dispatcher.contract_address, bob());

        // Attempt to call the upgrade function as a non-owner
        upgradeable_dispatcher.upgrade(new_class_hash);
    }
}
