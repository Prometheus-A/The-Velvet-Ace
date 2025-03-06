use starknet::ContractAddress;

// the locked variable takes in a tuple of (is_locked, game_id) if the player is already
// locked to a session.
// Hand should be a reference.

// FOR NOW, NO PLAYER CAN HAVE MORE THAN ONE HAND.
#[derive(Drop, Serde, Clone, Debug)]
#[dojo::model]
pub struct Player {
    #[key]
    id: ContractAddress,
    chips: u256,
    current_bet: u256,
    total_rounds: u64,
    locked: (bool, u64),
    is_dealer: bool,
}
