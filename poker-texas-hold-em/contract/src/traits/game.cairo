use poker::models::player::Player;
use poker::models::deck::{Deck, DeckTrait};
use poker::models::game::{Game, GameParams, GameMode};
use poker::models::base::GameErrors;
use poker::models::card::Card;

#[generate_trait]
pub impl GameImpl of GameTrait {
    fn initialize_game(ref player: Player, game_params: Option<GameParams>, id: u64) -> Game {
        // Set game parameters (either custom or default)
        let params = match game_params {
            Option::Some(params) => {
                // Validate custom params
                assert(params.max_no_of_players > 1, GameErrors::MIN_PLAYER);
                assert(params.big_blind > params.small_blind, GameErrors::INVALID_BLIND_PLAYER);
                params
            },
            Option::None => Self::get_default_game_params(),
        };

        let mut deck: Deck = Default::default();
        deck.new_deck(id);
        deck.shuffle();

        let mut players: Array<Option<Player>> = array![];
        let mut community_cards: Array<Card> = array![];

        // Ensure player has enough chips for the game
        assert(player.chips >= (params.big_blind * 20).into(), GameErrors::INSUFFICIENT_CHIP);

        // Set initial player as dealer
        player.is_dealer = true;

        // Lock player to this game
        player.locked = (true, id);

        // Add player to players array
        players.append(Option::Some(player.clone()));

        // Create game instance
        Game {
            id,
            in_progress: false,
            has_ended: false,
            current_round: 0,
            round_in_progress: false,
            players,
            deck,
            next_player: Option::None,
            community_cards,
            pot: 0,
            params,
        }
    }

    fn get_default_game_params() -> GameParams {
        GameParams {
            game_mode: GameMode::CashGame,
            max_no_of_players: 5,
            small_blind: 10,
            big_blind: 20,
            no_of_decks: 1,
            kicker_split: true,
            min_amount_of_chips: 10,
        }
    }

    fn leave_game(ref player: Player) { 
        // here, all player params should be re-initialized
    }
}
