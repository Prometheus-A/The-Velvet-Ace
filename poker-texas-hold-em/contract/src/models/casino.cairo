use starknet::ContractAddress;

/// Model to track casino/house funds collected from pot splits
/// This tracks the total funds collected by the casino from resolved hands
#[derive(Copy, Drop, Serde, Debug, Default, PartialEq)]
#[dojo::model]
pub struct CasinoFunds {
    #[key]
    id: u64, // Using game_id as key to track per-game collections
    total_collected: u256,
    last_collection_round: u64,
}

/// Event emitted when casino collects funds from pot splitting
#[derive(Drop, Serde)]
#[dojo::event]
pub struct CasinoCollection {
    #[key]
    game_id: u64,
    amount_collected: u256,
    round: u64,
    from_player: ContractAddress,
}
