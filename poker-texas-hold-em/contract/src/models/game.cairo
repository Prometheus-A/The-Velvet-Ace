use starknet::ContractAddress;
use super::card::Card;
use poker::traits::game::GameTrait;
use core::num::traits::Zero;

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
    max_no_of_players: u32,
    small_blind: u64,
    big_blind: u64,
    no_of_decks: u8,
    kicker_split: bool,
    min_amount_of_chips: u256,
    blind_spacing: u16,
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
/// deck - the decks in the game (id, referenced to the deck model)
/// next_player - the next player to take a turn
/// community - cards - the available community cards in the game
/// pot - the pot returning the pot size
/// current_bet - The current bet (current highest bet, targeted for a raise or call.)
/// params - the gameparams used to initialize the game.
#[derive(Drop, Default, Clone, Serde)]
#[dojo::model]
pub struct Game {
    #[key]
    id: u64,
    in_progress: bool,
    has_ended: bool,
    current_round: u8,
    round_in_progress: bool,
    current_player_count: u32,
    players: Array<ContractAddress>,
    deck: Array<u64>,
    next_player: Option<ContractAddress>,
    community_cards: Array<Card>,
    pot: u256,
    current_bet: u256,
    params: GameParams,
    reshuffled: u64,
}

// then we can implemnt a list node here
#[derive(Drop, Serde, Copy, PartialEq)]
pub struct Node {
    pub val: ContractAddress,
    pub next: Span<Node>,
}

// impl NodeSerde<T, +Serde<T>> of Serde<Node<T>> {
//     fn serialize(self: @Node<T>, ref output: Array<felt252>) {
//         // Implement serialization logic here
//         output.append(Serde::serialize(self.val));
//         output.append(Serde::serialize(*self.next));
//     }

//     fn deserialize(data: Span<u8>) -> Node<T> {
//         // Implement deserialization logic here
//         let val = Serde::deserialize(data.slice(0, data.len() / 2));
//         let next = Serde::deserialize(data.slice(data.len() / 2, data.len()));
//         Node { val, next }
//     }
// }

#[derive(Drop, Serde, Copy, PartialEq)]
pub struct ContractList {
    pub head: Node,
    pub tail: Node,
    pub count: u64,
}

pub trait ListTrait<T, V> {
    fn new() -> T;
    fn append(ref self: T, val: V);
    fn insert(ref self: T, val: V, index: u32);
    fn get(self: @T, index: u32) -> Option<V>;
    fn remove(ref self: T, index: u32) -> bool;
}

pub impl ContractListImpl of ListTrait<ContractList, ContractAddress> {
    fn new() -> ContractList {
        let node = Node { val: Zero::zero(), next: array![].span() };
        ContractList { head: node, tail: node, count: 0 }
    }

    fn append(ref self: ContractList, val: ContractAddress) {}

    fn insert(ref self: ContractList, val: ContractAddress, index: u32) {}

    fn get(self: @ContractList, index: u32) -> Option<ContractAddress> {
        Option::None
    }

    fn remove(ref self: ContractList, index: u32) -> bool {
        false
    }
}
// public class LinkedList {

//     private class Node {
//         int val;
//         Node next;
//     }

// Node head;
// Node tail;

// public int get(int index) {
//     int iterator = 0;
//     Node node = head;

//     while (node != null) {
//         if (iterator == index) {
//             return node.val;
//         }
//         iterator++;
//         node = node.next;
//     }
//     return -1;
// }

// public void insertHead(int val) {
//     Node node = new Node();
//     node.val = val;
//     if (head == null) {
//         head = node;
//         tail = node;
//     } else {
//         node.next = head;
//         head = node;
//     }
// }

// public void insertTail(int val) {
//     Node newNode = new Node();
//     newNode.val = val;
//         if (head == null) {
//             head = newNode;
//             tail = newNode;
//         } else {
//             Node node = head;
//             while (node.next != null) {
//                 node = node.next;
//             }
//             node.next = newNode;

// //            tail.next = newNode;
// //            tail = newNode;
//         }
//     }

//     public boolean remove(int index) {
//         Node previous = null;
//         Node current = head;
//         int i = 0;

//         while (current != null){
//             if (i == index) {
//                 if (previous == null) {
//                     head = head.next;
//                     return true;
//                 }
//                 System.out.println(i + " equals "+ index);
//                 previous.next = current.next;
//                 return true;
//             }
//             previous = current;
//             current = current.next;
//             i++;
//         }
//         return false;
//     }

//     public ArrayList<Integer> getValues() {
//         ArrayList<Integer> values = new ArrayList<>();
//         Node node = head;
//         while (node != null) {
//             values.add(node.val);
//             node = node.next;
//         }
//         return values;
//     }
// }


