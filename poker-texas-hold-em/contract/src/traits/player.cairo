use poker::models::player::Player;
use poker::models::game::{Game, ShowdownType};
use poker::models::base::GameErrors;
use super::game::GameTrait;

#[generate_trait]
pub impl PlayerImpl of PlayerTrait {
    fn exit(ref self: Player, ref game: Game, out: bool) {
        let (is_locked, id) = self.locked;
        assert(is_locked, 'CANNOT EXIT, PLAYER NOT LOCKED');
        assert(game.current_player_count != 0, 'GAME PLAYER COUNT SUB'); // sub overflow guard
        if out {
            // check game id
            assert(id == game.id, 'BAD REQUEST');
            self.out = (game.id, game.reshuffled);
        } else {
            self.out = (0, 0);
        }

        self.current_bet = 0;
        self.is_dealer = false;
        self.in_round = false;
        self.locked = (false, 0);

        if let ShowdownType::Splitted(stake) = game.params.showdown_type {
            if self.locked_chips == stake {
                self.chips += stake;
                self.locked_chips = 0;
            }
        }

        game.current_player_count -= 1;
    }

    fn enter(ref self: Player, ref game: Game) -> bool {
        assert(game.is_initialized(), GameErrors::GAME_NOT_INITIALIZED);
        assert(!game.has_ended, GameErrors::GAME_ALREADY_ENDED);
        assert(game.is_allowable(), GameErrors::ENTRY_DISALLOWED);

        let res: bool = self.enter_first_player(ref game);
        res
    }

    fn enter_first_player(ref self: Player, ref game: Game) -> bool {
        let (is_locked, _) = self.locked;
        assert(!is_locked, GameErrors::PLAYER_ALREADY_LOCKED);
        assert(self.refresh_stake(ref game), GameErrors::INSUFFICIENT_CHIP);

        if (game.id, game.reshuffled) != self.out {
            game.players.append(self.id);
        }
        self.locked = (true, game.id);
        self.in_round = true;
        game.current_player_count += 1;
        self.eligible_pots = 1;

        game.current_player_count == game.params.max_no_of_players
    }

    fn refresh_stake(ref self: Player, ref game: Game) -> bool {
        if let ShowdownType::Splitted(stake) = game.params.showdown_type {
            if stake >= self.chips {
                return false;
            }
            if self.locked_chips == stake {
                return true;
            }
            let amt = self.chips - stake;
            if game.params.min_amount_of_chips >= amt {
                return false;
            }
            self.chips -= stake;
            self.locked_chips += stake;
        }
        true
    }

    fn is_maxed(self: @Player, game: @Game) -> bool {
        self.is_in_game(*game.id)
            && *self.chips == 0
            && *self.eligible_pots < game.pots.len().try_into().unwrap()
            && *self.current_bet == 0
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
