use core::ops::IndexView;
use starknet::{ContractAddress};
use core::poseidon::{PoseidonTrait};
use core::hash::{HashStateTrait, HashStateExTrait};

#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
pub struct Card {
    suit: u8,
    value: u16
}

pub const DEFAULT_NO_OF_CARDS: u8 = 52;

/// CashGame. same as the `true` value for the Tournament. CashGame should allow incoming players...
/// may be refactored in the future.
/// Tournament. for Buying back-in after a certain period of time (can be removed),
/// false for Elimination when chips are out. 
#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
pub enum GameMode {
    CashGame,
    Tournament: bool,
}

#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
pub struct GameParams {
    game_mode: GameMode,
    max_no_of_players: u8,
    small_blind: u64,
    big_blind: u64,
    no_of_decks: u8,
}

/// id - the game id
/// in_progress - boolean if the game is in progress or not
/// has_ended - if the game has ended. Note that the difference between this and the former is
/// to check for "init" and "waiting". A game is initialized, and waiting for players, but the game
/// is not in progress yet. for waiting, check the has_ended and the in_progress.
/// 
/// current_round - stores the current round of the game for future operations
/// round_in_progress - set to true and false, when a round starts and when it ends respectively
/// this is to assert that any incoming player of a default game doesn't join when a round is in progress
/// 
/// players - The players in the current game
/// deck - the deck in the game
/// next_player - the next player to take a turn
/// community - cards - the available community cards in the game
/// pot - the pot returning the pot size
/// params - the gameparams used to initialize the game.
#[derive(Drop, Serde)]
#[dojo::model]
pub struct Game {
    #[key]
    id: felt252,
    in_progress: bool,
    has_ended: bool,
    current_round: u8,
    round_in_progress: bool,
    players: Array<Player>,
    deck: Deck,
    next_player: Player,
    community_cards: Array<Card>,
    pot: u256,
    params: GameParams
}

pub mod Suits {
    pub const SPADES: u8 = 0;
    pub const HEARTS: u8 = 1;
    pub const DIAMONDS: u8 = 2;
    pub const CLUBS: u8 = 3;
}

#[derive(Serde, Drop, Introspect, PartialEq)]
#[dojo::model]
pub struct Deck {
    #[key]
    game_id: felt252,
    cards: Array<Card>,
}

#[derive(Serde, Drop, Introspect)]
#[dojo::model]
pub struct Hand {
    #[key]
    player: ContractAddress,
    cards: Array<Card>
}

// the locked variable takes in a tuple of (is_locked, game_id) if the player is already
// locked to a session.
#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Player {
    #[key]
    id: ContractAddress,
    hand: Option<Hand>,
    chips: u128,
    current_bet: u64,
    total_rounds: u64,
    locked: (bool, u64)
}

pub mod Royals {
    pub const ACE: u16 = 1;
    pub const JACK: u16 = 11;
    pub const QUEEN: u16 = 12;
    pub const KING: u16 = 13;
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
#[dojo::model]
pub struct GameId {
    #[key]
    pub id: felt252,
    pub nonce: u64,
}

/// This is the hand ranks of player hand cards plus part of the community cards to make it 5 in
/// total
/// ROYAL_FLUSH: Ace, King, Queen, Jack and 10, all of the same suit.
/// STRAIGHT_FLUSH: Five cards in a row, all of the same suit.
/// FOUR_OF_A_KIND: Four cards of the same rank (or value as in the model)
/// FULL_HOUSE: Three cards of one rank (value) and two cards of another rank (value)
/// FLUSH: Five cards of the same suit
/// STRAIGHT: Five cards in a row, but not of the same suit
/// THREE_OF_A_KIND: Three cards of the same rank.
/// TWO_PAIR: Two cards of one rank, and two cards of another rank.
/// ONE_PAIR: Two cards of the same rank.
/// HIGH_CARD: None of the above.
pub mod HandRank {
    pub const ROYAL_FLUSH: u16 = 10; 
    pub const STRAIGHT_FLUSH: u16 = 9;
    pub const FOUR_OF_A_KIND: u16 = 8;
    pub const FULL_HOUSE: u16 = 7;
    pub const FLUSH: u16 = 6; 
    pub const STRAIGHT: u16 = 5;
    pub const THREE_OF_A_KIND: u16 = 4; 
    pub const TWO_PAIR: u16 = 3; 
    pub const ONE_PAIR: u16 = 2; 
    pub const HIGH_CARD: u16 = 1;
}

#[generate_trait]
pub impl HandImpl of HandTrait {
    /// This function will return the hand rank of the player's hand
    /// this will compare the cards on the player's hand with the community cards
    fn hand_rank(player: @Player, community_cards: @Array<Card>) -> u16 {
        0
    }

    /// This function will compare the hands of all the players and return the winning hand.
    fn compare_hands(players: @Array<Player>, community_cards: @Array<Card>) -> Player {
        
    }
    
    fn new_hand(player: ContractAddress) -> Hand {
        Hand { player, cards: array![] }
    }

    fn remove_card(position: u8, ref hand: Hand) {
        // ensure card is removed.
    }

    fn add_card(card: Card, ref hand: Hand) {
        // ensure card is added.
    }
}

#[generate_trait]
pub impl GameImpl of GameTrait {
    fn initialize_game(player: Option<Player>, game_params: Option<GameParams>) -> Game {
        if let game_params_ref = Option::Some(game_params) {

        }
        
    }

    fn get_default_game_params() -> GameParams {
        GameParams {
            game_mode: GameMode::CashGame,
            max_no_of_players: 5,
            small_blind: 10,
            big_blind: 20,
            no_of_decks: 1
        }
    }

    fn leave_game(player)
}

pub const DEFAULT_DECK_LENGTH: u32 = 52;

#[generate_trait]
pub impl DeckImpl of DeckTrait {
    fn new_deck(game_id: felt252) -> Deck {
        let mut cards: Array<Card> = array![];
        for suit in 0_u8..4_u8 {
            for value in 1_u16..14_u16 {
                let card: Card = Card {
                    suit,
                    value
                };
                cards.append(card);
            };
        };

        Deck {
            game_id,
            cards
        }
    }

    fn shuffle(mut deck: Deck) -> Deck {
        let mut cards: Array<Card> = deck.cards;
        let mut new_cards: Array<Card> = array![];
        let mut verifier: Felt252Dict<bool> = Default::default();
        for _ in cards.len()..0 {
            let mut rand = Self::_generate_random(DEFAULT_DECK_LENGTH);
            while ! verifier.get(rand.into()) {
                rand = Self::_generate_random(DEFAULT_DECK_LENGTH);
            };
            let temp: Card = *cards.at(rand);
            new_cards.append(temp);
            verifier.insert(rand.into(), true);
        };

        deck.cards = new_cards;
        deck
    }

    fn _generate_random(span: u32) -> u32 {
        let seed = starknet::get_block_timestamp();
        let hash: u256 = PoseidonTrait::new().update_with(seed).finalize().into();

        (hash % span.into()).try_into().unwrap()
    }

    fn deal_card(mut deck: Deck) -> (Deck, Card) {
        let previous_size = deck.cards.len();
        assert_ne!(previous_size, 0);
        let card: Card = deck.cards.pop_front().unwrap();
        assert_gt!(previous_size, deck.cards.len());

        (deck, card)
    }
}

pub mod GameErrors {
    pub const GAME_NOT_INITIALIZED: felt252 = 'GAME NOT INITIALIZED';
    pub const GAME_ALREADY_STARTED: felt252 = 'GAME ALREADY STARTED';
    pub const GAME_ALREADY_ENDED: felt252 = 'GAME ALREADY ENDED';
    pub const PLAYER_NOT_IN_GAME: felt252 = 'PLAYER NOT IN GAME';
    pub const PLAYER_ALREADY_IN_GAME: felt252 = 'PLAYER ALREADY IN GAME';
}

// assert after shuffling, that all cards remain distinct, and the deck is still 52 cards
// #[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug)]


