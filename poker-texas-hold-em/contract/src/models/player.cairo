use starknet::ContractAddress;
use core::num::traits::Zero;
use super::base::GameErrors;
use super::game::{Game, GameTrait, GameMode};

// the locked variable takes in a tuple of (is_locked, game_id) if the player is already
// locked to a session.
// Hand should be a reference.

// FOR NOW, NO PLAYER CAN HAVE MORE THAN ONE HAND.
// Go to all funcrtions that use player as a parameter, and remove the snapshot
#[derive(Drop, Serde, Debug)]
#[dojo::model]
pub struct Player {
    #[key]
    id: ContractAddress,
    #[key]
    alias: felt252,
    chips: u256,
    current_bet: u256,
    total_rounds: u64,
    locked: (bool, u64),
    is_dealer: bool,
    in_round: bool,
    out: (u64, u64),
}
/// Write struct for player stats
/// Include an alias, if necessary, and add it as key.
/// TODO: ABOVE

pub fn get_default_player() -> Player {
    Player {
        id: Zero::zero(),
        alias: '',
        chips: 0,
        current_bet: 0,
        total_rounds: 0,
        locked: (false, 0),
        is_dealer: false,
        in_round: false,
        out: (0, 0),
    }
}

#[generate_trait]
pub impl PlayerImpl of PlayerTrait {
    fn exit(ref self: Player, ref game: Game, out: bool) {
        let (is_locked, id) = self.locked;
        assert(is_locked, 'CANNOT EXIT, PLAYER NOT LOCKED');
        assert(game.current_player_count != 0, 'GAME PLAYER COUNT SUB');
        if out {
            // check game id
            assert(id == game.id, 'BAD REQUEST');
            self.out = (game.id, game.reshuffled);
        }

        self.current_bet = 0;
        self.is_dealer = false;
        self.in_round = false;
        self.locked = (false, 0);
        self.out = (0, 0);

        game.current_player_count -= 1;
    }

    fn enter(ref self: Player, ref game: Game) {
        let (is_locked, _) = self.locked;
        assert(!is_locked, GameErrors::PLAYER_ALREADY_LOCKED);
        // Ensure player has enough chips for the game
        assert(self.chips >= game.params.min_amount_of_chips, GameErrors::INSUFFICIENT_CHIP);
        assert(game.is_initialized(), GameErrors::GAME_NOT_INITIALIZED);
        assert(!game.has_ended, GameErrors::GAME_ALREADY_ENDED);
        assert(game.is_allowable(), GameErrors::ENTRY_DISALLOWED);

        if (game.id, game.reshuffled) != self.out {
            // append. Player doesn't exist in the game
            game.players.append(self.id);
        } // should work.
        self.locked = (true, game.id);
        self.in_round = true;
        game.current_player_count += 1;
    }

    fn extract_current_game_id(self: @Player) -> @u64 {
        let (is_locked, game_id) = self.locked;
        assert(*is_locked, GameErrors::PLAYER_NOT_IN_GAME);
        assert(*game_id != 0, GameErrors::PLAYER_NOT_IN_GAME);

        game_id
    }

    fn is_in_game(self: @Player, game_id: u64) -> bool {
        let (is_locked, id) = self.locked;
        *is_locked && id == @game_id
    }
}
