/// A logic that verifies that all cards are shuffled and distinct from one another

use crate::models::card::{Card, CardTrait};
use crate::models::deck::{Deck, DeckTrait};
use crate::models::hand::Hand;
use super::game::MerkleTrait;

/// @Birdmannn
/// Verifies the deck in sync with the whole game.
///
/// Implements lazy verification
/// This function ensures that the whole gameplay was indeed performed accurately, after the game
/// round has been concluded.
///
/// # Arguments
/// * `community_cards` - An array of community cards dealt in the round
/// * `hands` - An array of player hands submitted during showdown
/// * `proofs` - Merkle proofs of player hands for verification
/// * `deck` - The current deck used in playing the game
/// * `game_root` - The merkle root of the deck in the game.
/// * `dealt_cards_root` - The merkle root of the dealt cards in the game
/// * `salt` - The salt used for cards commitment
///
/// # Returns
/// bool - if the game was valid.
/// no panic
/// TODO: IN THE FUTURE, PLEASE USE OPENZEPPELIN FOR MERKLE TREE VERIFICATION
pub fn verify_game(
    community_cards: Array<Card>,
    hands: Array<Hand>,
    mut game_proofs: Array<Array<felt252>>,
    mut dealt_cards_proofs: Array<Array<felt252>>,
    mut deck: Deck,
    game_root: felt252,
    dealt_cards_root: felt252,
    game_salt: Array<felt252>,
    dealt_card_salt: Array<felt252>,
) -> bool {
    assert(community_cards.len() == 5, 'COMMUNITY CARDS != 5');
    assert(hands.len() == game_proofs.len() / 2, 'PROOFS AND HANDS LEN MISMATCH');
    assert(hands.len() == dealt_cards_proofs.len() / 2, 'PROOFS AND HANDS LEN MISMATCH.');
    // rebuild deck, and compute the root.
    let deck_cards = deck.cards;
    deck.cards = array![];
    // append dealt hands first.
    for i in 0..hands.len() {
        let hand = hands.at(i);
        for j in 0..hand.cards.len() {
            deck.append(*hand.cards.at(j));
        };
    }

    // append community cards next.
    for i in 0..community_cards.len() {
        deck.append(*community_cards.at(i));
    }

    // then append the remaining deck cards
    for card in deck_cards {
        deck.append(card);
    }

    if !deck.is_shuffled() || !deck.is_cards_distinct() {
        return false;
    }

    // SWITCH TO OPENZEPPELIN IN THE FUTURE
    let mut merkle_state = MerkleTrait::new(deck.cards, game_salt.clone());
    if merkle_state.get_root() != game_root {
        return false;
    }

    // verify these hands were in the deck
    let mut card_index = 0;
    let mut deck_verified = false;
    let mut card_verified = false;
    for hand in hands {
        // let hand = hands.get(i).unwrap().unbox();
        for mut card in hand.cards {
            // it should take two at a time for the array of proofs
            let proof = game_proofs.pop_front().unwrap();
            let dealt_card_proof = dealt_cards_proofs.pop_front().unwrap();
            deck_verified = verify(proof, game_root, card, game_salt.clone(), card_index);
            card_verified =
                verify(
                    dealt_card_proof, dealt_cards_root, card, dealt_card_salt.clone(), card_index,
                );

            if !deck_verified || !card_verified {
                break;
            }
            card_index += 1;
        };
    }

    deck_verified && card_verified
}

fn verify(
    proof: Array<felt252>, root: felt252, mut card: Card, salt: Array<felt252>, index: usize,
) -> bool {
    MerkleTrait::verify_v2(proof, root, card.hash(salt), index)
}

// @augustin-v
// Helper function to count unique cards in a deck
// Returns the number of distinct cards based on their suit and value
pub fn count_unique_cards(deck: @Deck) -> u32 {
    let mut count: u32 = 0;
    let mut seen: Felt252Dict<bool> = Default::default();

    let cards: @Array<Card> = deck.cards;
    let cards_len: u32 = cards.len();

    let mut i: u32 = 0;
    while i < cards_len {
        let card = *cards.at(i);
        // Create a unique key for each card (suit * 100 + value)
        let key: felt252 = (card.suit.into() * 100 + card.value.into()).into();

        if !seen.get(key) {
            seen.insert(key, true);
            count += 1;
        }

        i += 1;
    }

    count
}

// fn _deal_hands(
//     ref self: ContractState, ref players: Array<Player>,
// ) { // deal hands for each player in the array
//     assert(!players.is_empty(), 'Players cannot be empty');

//     let first_player = players.at(0);
//     let game_id = first_player.extract_current_game_id();

//     for player in players.span() {
//         let current_game_id = player.extract_current_game_id();
//         assert(current_game_id == game_id, 'Players in different games');
//     };

//     let mut world = self.world_default();
//     let game: Game = world.read_model(*game_id);
//     // TODO: Check the number of decks, and deal card from each deck equally
//     let deck_ids: Array<u64> = game.deck;

//     // let mut deck: Deck = world.read_model(game_id);
//     let mut current_index: usize = 0;
//     for mut player in players.span() {
//         let mut hand: Hand = world.read_model(*player.id);
//         hand.new_hand();

//         for _ in 0_u8..2_u8 {
//             let index = current_index % deck_ids.len();
//             let deck_id: u64 = *deck_ids.at(index);
//             let mut deck: Deck = world.read_model(deck_id);
//             hand.add_card(deck.deal_card());

//             world.write_model(@deck); // should work, ;)
//             current_index += 1;
//         };

//         world.write_model(@hand);
//         world.write_model(player);
//     };
// }

#[cfg(test)]
mod Tests {
    use crate::models::card::{Card, Royals, Suits};
    use crate::models::deck::{Deck, DeckTrait};
    use crate::models::game::Game;
    use crate::models::hand::{Hand, HandTrait};
    use super::verify_game;
    use super::super::game::{MerkleState, MerkleTrait};

    fn card(suit: u8, value: u16) -> Card {
        Card { suit, value }
    }

    #[test]
    fn test_verify_game_success() {
        let mut deck: Deck = Default::default();
        let salt1 = array!['SALT1', 'SALT2', 'SALT3'];
        let salt2 = array!['SALT4', 'SALT5', 'SALT6'];
        deck.new_deck();
        deck.shuffle();
        let mut deck_state = MerkleTrait::new(deck.cards.clone(), salt1.clone());

        // deal cards
        let mut player1_hand = HandTrait::default();
        let mut player2_hand = HandTrait::default();
        let mut player_cards = array![];

        // index 1 and 2, for player1, and 3 and 4 for player2
        for _ in 0..2_u32 {
            let card = deck.deal_card();
            player1_hand.add_card(card);
            player_cards.append(card);
        }

        for _ in 0..2_u32 {
            let card = deck.deal_card();
            player2_hand.add_card(card);
            player_cards.append(card);
        }

        let mut dealt_cards_state = MerkleTrait::new(player_cards.clone(), salt2.clone());
        let mut community_cards = array![];
        for _ in 0..5_u32 {
            community_cards.append(deck.deal_card());
        }

        let hands = array![player1_hand, player2_hand];
        let mut game_proofs = array![];
        let mut dealt_cards_proofs = array![];
        for i in 0..player_cards.len() {
            let proof = deck_state.generate_proof_v2(i.into());
            game_proofs.append(proof);
            let proof = dealt_cards_state.generate_proof_v2(i.into());
            dealt_cards_proofs.append(proof);
        }
        let game_root = deck_state.get_root();
        println!("Game root in test: {}", game_root);
        let dealt_cards_root = dealt_cards_state.get_root();

        let is_verified = verify_game(
            community_cards,
            hands,
            game_proofs,
            dealt_cards_proofs,
            deck,
            game_root,
            dealt_cards_root,
            salt1,
            salt2,
        );

        assert(is_verified, 'UNABLE TO VERIFY GAME');
    }

    #[test]
    fn test_verify_game_on_wrong_proof() { // for a two player game
    // pub fn verify_game(
    //     community_cards: Array<Card>,
    //     hands: Array<Hand>,
    //     mut game_proofs: Array<Array<felt252>>,
    //     mut dealt_cards_proofs: Array<Array<felt252>>,
    //     mut deck: Deck,
    //     game_root: felt252,
    //     dealt_cards_root: felt252,
    //     game_salt: Array<felt252>,
    //     dealt_card_salt: Array<felt252>,
    // )
    }

    #[test]
    fn test_verify_game_on_wrong_data() { // this should be a fuzz test, by the way... if necessary.
    }
}

