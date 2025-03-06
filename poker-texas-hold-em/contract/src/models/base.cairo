/// TODO: make sure you create events
///
/// **********************************************************************************************

#[derive(Serde, Copy, Drop, PartialEq)]
#[dojo::model]
pub struct GameId {
    #[key]
    pub id: felt252,
    pub nonce: u64,
}

pub mod GameErrors {
    pub const GAME_NOT_INITIALIZED: felt252 = 'GAME NOT INITIALIZED';
    pub const GAME_ALREADY_STARTED: felt252 = 'GAME ALREADY STARTED';
    pub const GAME_ALREADY_ENDED: felt252 = 'GAME ALREADY ENDED';
    pub const PLAYER_NOT_IN_GAME: felt252 = 'PLAYER NOT IN GAME';
    pub const PLAYER_ALREADY_IN_GAME: felt252 = 'PLAYER ALREADY IN GAME';
    pub const PLAYER_ALREADY_LOCKED: felt252 = 'PLAYER ALREADY LOCKED';
    pub const PLAYER_OUT_OF_CHIPS: felt252 = 'PLAYER OUT OF CHIPS';
    pub const MIN_PLAYER: felt252 = 'MIN 2 PLAYERS REQUIRED';
    pub const INVALID_BLIND_PLAYER: felt252 = 'INVALID BLIND VALUES';
    pub const INSUFFICIENT_CHIP: felt252 = 'INSUFFICIENT CHIPS';
}
