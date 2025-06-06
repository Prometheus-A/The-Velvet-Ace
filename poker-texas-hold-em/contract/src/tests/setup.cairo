mod setup {
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait, WorldStorage, WorldStorageTrait};
    use dojo_cairo_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        deploy_contract, spawn_test_world,
    };
    use poker::systems::{actions::actions, interface::IActionsDispatcher};
    use starknet::testing::{set_account_contract_address, set_contract_address};
    use poker::models::base::{
        m_Id, e_GameInitialized, e_CardDealt, e_HandCreated, e_HandResolved, e_RoundResolved,
        e_PlayerJoined,
    };
    use poker::models::deck::m_Deck;
    use poker::models::game::m_Game;
    use poker::models::hand::m_Hand;
    use poker::models::player::m_Player;


    #[starknet::interface]
    trait IDojoInit<ContractState> {
        fn dojo_init(self: @ContractState);
    }

    #[derive(Drop)]
    struct Systems {
        actions: IActionsDispatcher,
    }

    #[derive(Drop)]
    enum CoreContract {
        Actions,
    }

    fn ACTIONS_MOD_NAME() -> ByteArray {
        "actions"
    }

    fn POKER_NAMESPACE() -> ByteArray {
        "poker"
    }

    fn deploy_contracts(core_contracts: Array<CoreContract>) -> (WorldStorage, Systems) {
        // [Contracts - Components]
        let mut cdefs = array![];
        let mut ndefs = _resolve_ndefs();

        // [Setup] Add rules to the world
        let mut world = spawn_test_world(
            array![NamespaceDef { namespace: POKER_NAMESPACE(), resources: ndefs.span() }].span(),
        );

        // [Contract Addresses] - Needed contracts will be initialized
        let mut actions_address = Zeroable::zero();

        for core_contract in core_contracts {
            match core_contract {
                CoreContract::Actions => {
                    let (address, _) = world.dns(@ACTIONS_MOD_NAME()).unwrap();
                    actions_address = address;
                    cdefs
                        .append(
                            ContractDefTrait::new(@POKER_NAMESPACE(), @ACTIONS_MOD_NAME())
                                .with_writer_of(
                                    array![dojo::utils::bytearray_hash(@POKER_NAMESPACE())].span(),
                                ),
                        );
                },
                _ => {
                    println!(
                        "[!] [deploy_contracts] - This contract type doesnt have any action and must be added",
                    );
                },
            }
        };
        world.sync_perms_and_inits(cdefs.span());

        let systems = Systems { actions: IActionsDispatcher { contract_address: actions_address } };

        // [Set] Caller back to owner
        let owner = starknet::get_contract_address();
        set_contract_address(owner);
        set_account_contract_address(owner);
        (world, systems)
    }

    // This could be more efficient but for now we only have just `actions contract`, so, do a match
    // and deploy specifics models doesnt seem very necessary for now
    fn _resolve_ndefs() -> Array<TestResource> {
        array![
            // Contracts
            TestResource::Contract(actions::TEST_CLASS_HASH),
            // Models
            TestResource::Model(m_Id::TEST_CLASS_HASH),
            TestResource::Model(m_Deck::TEST_CLASS_HASH),
            TestResource::Model(m_Hand::TEST_CLASS_HASH),
            TestResource::Model(m_Game::TEST_CLASS_HASH),
            TestResource::Model(m_Player::TEST_CLASS_HASH),
            // Events
            TestResource::Event(e_GameInitialized::TEST_CLASS_HASH),
            TestResource::Event(e_CardDealt::TEST_CLASS_HASH),
            TestResource::Event(e_HandCreated::TEST_CLASS_HASH),
            TestResource::Event(e_HandResolved::TEST_CLASS_HASH),
            TestResource::Event(e_PlayerJoined::TEST_CLASS_HASH),
            TestResource::Event(e_RoundResolved::TEST_CLASS_HASH),
        ]
    }
}
