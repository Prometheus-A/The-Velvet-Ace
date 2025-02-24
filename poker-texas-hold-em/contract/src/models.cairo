use core::ops::IndexView;
use starknet::{ContractAddress, contract_address_const};
use core::poseidon::{PoseidonTrait};
use core::hash::{HashStateTrait, HashStateExTrait};

/// TODO: make sure you create events
///
/// **********************************************************************************************

// Check the Suits struct
#[derive(Copy, Drop, Serde, Default, Debug, Introspect, PartialEq)]
pub struct Card {
    suit: u8,
    value: u16,
}

pub const DEFAULT_NO_OF_CARDS: u8 = 52;

/// CashGame. same as the `true` value for the Tournament. CashGame should allow incoming players...
/// may be refactored in the future.
/// Tournament. for Buying back-in after a certain period of time (can be removed),
/// false for Elimination when chips are out.
#[derive(Copy, Drop, Serde, Default, Introspect, PartialEq)]
pub enum GameMode {
    #[default]
    CashGame,
    Tournament: bool,
}

/// The kicker_split is checked when comparing hands.
#[derive(Copy, Drop, Serde, Default, Introspect, PartialEq)]
pub struct GameParams {
    game_mode: GameMode,
    max_no_of_players: u8,
    small_blind: u64,
    big_blind: u64,
    no_of_decks: u8,
    kicker_split: bool,
}

/// id - the game id
/// in_progress - boolean if the game is in progress or not
/// has_ended - if the game has ended. Note that the difference between this and the former is
/// to check for "init" and "waiting". A game is initialized, and waiting for players, but the game
/// is not in progress yet. for waiting, check the has_ended and the in_progress.
///
/// current_round - stores the current round of the game for future operations
/// round_in_progress - set to true and false, when a round starts and when it ends respectively
/// this is to assert that any incoming player of a default game doesn't join when a round is in
/// progress
///
/// players - The players in the current game
/// deck - the deck in the game
/// next_player - the next player to take a turn
/// community - cards - the available community cards in the game
/// pot - the pot returning the pot size
/// params - the gameparams used to initialize the game.
#[derive(Drop, Default, Serde)]
#[dojo::model]
pub struct Game {
    #[key]
    id: u64,
    in_progress: bool,
    has_ended: bool,
    current_round: u8,
    round_in_progress: bool,
    players: Array<Option<Player>>,
    deck: Deck,
    next_player: Option<Player>,
    community_cards: Array<Card>,
    pot: u256,
    params: GameParams,
}

pub mod Suits {
    pub const SPADES: u8 = 0;
    pub const HEARTS: u8 = 1;
    pub const DIAMONDS: u8 = 2;
    pub const CLUBS: u8 = 3;
}

#[derive(Serde, Drop, Clone, Default, Introspect, PartialEq)]
#[dojo::model]
pub struct Deck {
    #[key]
    game_id: felt252,
    cards: Array<Card>,
}

#[derive(Serde, Drop, Clone, Debug, Introspect)]
#[dojo::model]
pub struct Hand {
    #[key]
    player: ContractAddress,
    cards: Array<Card>,
}

// the locked variable takes in a tuple of (is_locked, game_id) if the player is already
// locked to a session.
#[derive(Drop, Serde, Clone, Debug)]
#[dojo::model]
pub struct Player {
    #[key]
    id: ContractAddress,
    hand: Hand,
    chips: u256,
    current_bet: u256,
    total_rounds: u64,
    locked: (bool, u64),
    is_dealer: bool,
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
    fn hand_rank(player: Player, community_cards: Array<Card>) -> (Hand, u16) {
        // use HandRank to get the rank for a hand of one player
        // return using the HandRank::<the const>, and not the raw u16 value
        // compute the hand that makes up this rank you have computed
        // set the player value (a CA) to the player's CA with the particular hand
        // return both values in a tuple
        // document the function.

        // this function can be called externally in the future.

        (Self::new_hand(contract_address_const::<0x0>()), 0)
    }

    /// This function will compare the hands of all the players and return an array of Player
    /// contains the player with the winning hand
    /// this is only possible if the `kick_split` in game_params is true
    fn compare_hands(
        players: Array<Player>, community_cards: Array<Card>, game_params: GameParams,
    ) -> Array<Option<Player>> {
        // for hand comparisons, there should be a kicker
        // kicker there-in that there are times two or more players have the same hand rank, so we
        // check the value of each card in hand.

        // TODO: Ace might be changed to a higher value.
        let mut highest_rank: u16 = 0;
        let mut current_winner: Option<Player> = Option::None;
        let mut current_winning_hand: Hand = Self::new_hand(contract_address_const::<0x0>());
        let mut winning_players: Array<Option<Player>> = array![];
        let mut winning_hands: Array<Hand> = array![];
        for player in players {
            let (hand, current_rank) = Self::hand_rank(player.clone(), community_cards.clone());
            if current_rank > highest_rank {
                highest_rank = current_rank;
                current_winner = Option::Some(player.clone());
                current_winning_hand = hand;
                // append details into `winning_hands` -- extracted using a bool variables
                // `hands_changed`
                // the hands has been changed, set to true
                Self::hands_changed(ref winning_players, ref winning_hands, true);
                // update the necessary arrays here.

            } else if current_rank == highest_rank {
                // implement kicker. Only works for the current_winner variable
                // retrieve the former current_winner already stored and the current player,
                // and compare both hands. This should be done in another internal function and be
                // called here.
                // The function should take in both `hand` and `current_winning_hand`, should return
                // the winning hand Implementation would be left to you
                // compare the player's CA in the returned hand to the current `winning_hand`
                // If not equal, update both `current_winner` and `winning_hand`

                // TODO: Check for a straight. The kicker is different for a straight. The person
                // with the highest straight wins (compare only the last straight.) The function
                // called here might take in a `hand_rank` u16 variable to check for this.

                // in rare case scenarios, a pot can be split based on the game params
                // here, an array shall be used. check kicker_split, if true, add two same hands in
                // the array Add the kicker hand first into the array, before the other...that's if
                // `game_params.kicker_split`
                // is true, if not, add only the kicker hand to the Array. For more than two
                // kickers, arrange the array accordingly. might be implemented by someone else.
                // here, hands have been changed, right?
                Self::hands_changed(ref winning_players, ref winning_hands, true);
                // do the necessary updates.
            }
        };

        winning_players
    }

    // To be audited
    fn hands_changed(
        ref winning_players: Array<Option<Player>>,
        ref winning_hands: Array<Hand>,
        hands_changed: bool,
    ) {
        if hands_changed {
            assert(winning_hands.len() == winning_players.len(), 'HandImpl panicked.');
            for _ in 0..winning_hands.len() {
                // discard all existing objects in `winning_hands`. A clean slate.
                winning_hands.pop_front().unwrap();
                winning_players.pop_front().unwrap().unwrap();
            };
        }
    }

    fn new_hand(player: ContractAddress) -> Hand {
        Hand { player, cards: array![] }
    }

    fn remove_card(position: u8, ref hand: Hand) { // ensure card is removed.
    // though I haven't seen a need for this function.
    }

    fn add_card(card: Card, ref hand: Hand) { // ensure card is added.
    }
}

#[generate_trait]
pub impl GameImpl of GameTrait {
    fn initialize_game(player: Option<Player>, game_params: Option<GameParams>, id: u64) -> Game {
        let mut game: Game = Default::default();
        match game_params {
            Option::Some(params) => params,
            _ => Self::get_default_game_params(),
        }

        // pub struct Game {
        //     #[key]
        //     id: u64,
        //     in_progress: bool,
        //     has_ended: bool,
        //     current_round: u8,
        //     round_in_progress: bool,
        //     players: Array<Option<Player>>,
        //     deck: Deck,
        //     next_player: Option<Player>,
        //     community_cards: Array<Card>,
        //     pot: u256,
        //     params: GameParams
        // }
        game
    }

    fn get_default_game_params() -> GameParams {
        GameParams {
            game_mode: GameMode::CashGame,
            max_no_of_players: 5,
            small_blind: 10,
            big_blind: 20,
            no_of_decks: 1,
            kicker_split: true,
        }
    }

    fn leave_game(ref player: Player) { // here, all player params should be re-initialized
    }
}

pub const DEFAULT_DECK_LENGTH: u32 = 52; // move this up up

fn generate_random(span: u32) -> u32 {
    let seed = starknet::get_block_timestamp();
    let hash: u256 = PoseidonTrait::new().update_with(seed).finalize().into();

    (hash % span.into()).try_into().unwrap()
}

pub impl DeckImpl of DeckTrait<Deck> {
    fn new_deck(ref self: Deck, game_id: felt252) -> Deck {
        let mut cards: Array<Card> = array![];
        for suit in 0_u8..4_u8 {
            for value in 1_u16..14_u16 {
                let card: Card = Card { suit, value };
                cards.append(card);
            };
        };

        Deck { game_id, cards }
    }

    fn shuffle(ref self: Deck) {
        let mut cards: Array<Card> = self.cards;
        let mut new_cards: Array<Card> = array![];
        let mut verifier: Felt252Dict<bool> = Default::default();
        for _ in cards.len()..0 {
            let mut rand = generate_random(DEFAULT_DECK_LENGTH);
            while !verifier.get(rand.into()) {
                rand = generate_random(DEFAULT_DECK_LENGTH);
            };
            let temp: Card = *cards.at(rand);
            new_cards.append(temp);
            verifier.insert(rand.into(), true);
        };

        self.cards = new_cards.clone();
        // deck
    }

    fn deal_card(ref self: Deck) -> Card {
        let previous_size = self.cards.len();
        // assert_ne(previous_size, 0);
        let card: Card = self.cards.pop_front().unwrap();
        // assert_gt!(previous_size, deck.cards.len());

        card
    }
}

pub mod GameErrors {
    pub const GAME_NOT_INITIALIZED: felt252 = 'GAME NOT INITIALIZED';
    pub const GAME_ALREADY_STARTED: felt252 = 'GAME ALREADY STARTED';
    pub const GAME_ALREADY_ENDED: felt252 = 'GAME ALREADY ENDED';
    pub const PLAYER_NOT_IN_GAME: felt252 = 'PLAYER NOT IN GAME';
    pub const PLAYER_ALREADY_IN_GAME: felt252 = 'PLAYER ALREADY IN GAME';
    pub const PLAYER_OUT_OF_CHIPS: felt252 = 'PLAYER OUT OF CHIPS';
}
// assert after shuffling, that all cards remain distinct, and the deck is still 52 cards
// #[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug)]

pub trait DeckTrait<T> {
    fn new_deck(ref self: T, game_id: felt252) -> Deck;
    fn shuffle(ref self: T);
    fn deal_card(ref self: T) -> Card;
}

