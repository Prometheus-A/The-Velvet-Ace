/// TODO: make sure you create events
///
/// **********************************************************************************************
/// Events
use poker::models::game::GameParams;
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GameInitialized {
    #[key]
    pub game_id: u64,
    pub player: ContractAddress,
    pub game_params: GameParams,
    pub time_stamp: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct CardDealt {
    #[key]
    pub game_id: u64,
    pub player_id: ContractAddress,
    pub deck_id: u64,
    pub time_stamp: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct HandCreated {
    #[key]
    pub game_id: u64,
    pub player_id: ContractAddress,
    pub time_stamp: u64,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct HandResolved {
    #[key]
    pub game_id: u64,
    pub players: Array<ContractAddress>,
}

#[derive(Drop, Serde)]
#[dojo::event]
struct RoundResolved {
    #[key]
    pub game_id: u64,
    pub can_join: bool,
}

#[derive(Serde, Copy, Drop, PartialEq)]
#[dojo::model]
pub struct Id {
    #[key]
    pub id: felt252,
    pub nonce: u64,
}

pub mod GameErrors {
    pub const GAME_NOT_INITIALIZED: felt252 = 'GAME NOT INITIALIZED';
    pub const GAME_ALREADY_STARTED: felt252 = 'GAME ALREADY STARTED';
    pub const GAME_ALREADY_ENDED: felt252 = 'GAME ALREADY ENDED';
    pub const GAME_NOT_IN_PROGRESS: felt252 = 'GAME NOT IN PROGRESS';
    pub const PLAYER_NOT_IN_GAME: felt252 = 'PLAYER NOT IN GAME';
    pub const PLAYER_ALREADY_IN_GAME: felt252 = 'PLAYER ALREADY IN GAME';
    pub const PLAYER_ALREADY_LOCKED: felt252 = 'PLAYER ALREADY LOCKED';
    pub const PLAYER_OUT_OF_CHIPS: felt252 = 'PLAYER OUT OF CHIPS';
    pub const ROUND_NOT_IN_PROGRESS: felt252 = 'ROUND NOT IN PROGRESS';
    pub const MIN_PLAYER: felt252 = 'MIN 2 PLAYERS REQUIRED';
    pub const INVALID_BLIND_PLAYER: felt252 = 'INVALID BLIND VALUES';
    pub const INSUFFICIENT_CHIP: felt252 = 'INSUFFICIENT CHIPS';
    pub const INVALID_GAME_PARAMS: felt252 = 'INVALID GAME PARAMS';
    pub const ENTRY_DISALLOWED: felt252 = 'ENTRY DISALLOWED';
    pub const COMMUNITY_CARDS_FULL: felt252 = 'COMMUNITY_CARDS_FULL';
    pub const NO_DECKS_AVAILABLE: felt252 = 'NO_DECKS_AVAILABLE';
}
