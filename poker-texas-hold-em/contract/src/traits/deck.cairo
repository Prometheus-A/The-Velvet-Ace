use core::ops::IndexView;
use starknet::{ContractAddress, contract_address_const};
use core::poseidon::{PoseidonTrait};
use core::hash::{HashStateTrait, HashStateExTrait};
use poker::models::deck::Deck;
use poker::models::card::Card;

pub const DEFAULT_DECK_LENGTH: u32 = 52; // move this up up

fn generate_random(span: u32) -> u32 {
    let seed = starknet::get_block_timestamp();
    let hash: u256 = PoseidonTrait::new().update_with(seed).finalize().into();

    (hash % span.into()).try_into().unwrap()
}

#[generate_trait]
pub impl DeckImpl of DeckTrait {
    fn new_deck(ref self: Deck) {
        let mut cards: Array<Card> = array![];
        for suit in 0_u8
            ..4_u8 {
                for value in 1_u16
                    ..14_u16 {
                        let card: Card = Card { suit, value };
                        cards.append(card);
                    };
            };

        self.cards = cards;
    }

    fn shuffle(ref self: Deck) {
        let mut cards: Array<Card> = self.cards;
        let mut new_cards: Array<Card> = array![];
        let mut verifier: Felt252Dict<bool> = Default::default();
        for _ in cards.len()
            ..0 {
                let mut rand = generate_random(DEFAULT_DECK_LENGTH);
                while verifier.get(rand.into()) {
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
        self.cards.pop_front().unwrap()
    }
}
// assert after shuffling, that all cards remain distinct, and the deck is still 52 cards
// #[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug)]


