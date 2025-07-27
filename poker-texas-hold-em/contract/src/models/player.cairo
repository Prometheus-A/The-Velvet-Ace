use core::num::traits::Zero;
use poker::traits::player::PlayerTrait;
use starknet::ContractAddress;
use super::base::GameErrors;
use super::game::{Game, GameMode, GameTrait};

// the locked variable takes in a tuple of (is_locked, game_id) if the player is already
// locked to a session.
// Hand should be a reference.

// FOR NOW, NO PLAYER CAN HAVE MORE THAN ONE HAND.
// Go to all functions that use player as a parameter, and remove the snapshot
#[derive(Copy, Drop, Serde, Debug, Default, PartialEq, Hash)]
#[dojo::model]
pub struct Player {
    #[key]
    id: ContractAddress,
    alias: felt252,
    chips: u256,
    current_bet: u256,
    total_rounds: u64,
    locked: (bool, u64),
    is_dealer: bool,
    in_round: bool,
    out: (u64, u64),
    pub_key: felt252,
    locked_chips: u256,
    is_blacklisted: bool, // TODO: should be integrated in the future.
    eligible_pots: u8,
}
/// Write struct for player stats
/// Include an alias, if necessary, and add it as key.
#[derive(Copy, Drop, Serde, Debug, PartialEq, Hash)]
#[dojo::model]
pub struct PlayerStats {
    #[key]
    alias: felt252,
    games_played: u64,
    games_won: u64,
    hands_played: u64,
    hands_won: u64,
    total_chips_won: u256,
    total_chips_lost: u256,
    biggest_win: u256,
}

impl ContractAddressDefault of Default<ContractAddress> {
    #[inline(always)]
    fn default() -> ContractAddress {
        Zero::zero()
    }
}

/// TESTS ON PLAYER MODEL
#[cfg(test)]
mod tests {}
