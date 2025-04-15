use poker::models::player::Player;
use poker::models::game::Game;
use poker::models::base::GameErrors;
use super::game::GameTrait;

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

    fn enter(ref self: Player, ref game: Game) -> bool {
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

        game.current_player_count == game.params.max_no_of_players
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
