use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::{PoseidonTrait, hades_permutation, poseidon_hash_span};
use crate::models::card::{Card, CardTrait};
use crate::models::deck::Deck;

#[derive(Drop, Clone, Serde, Default)]
pub struct MerkleState {
    tree: Array<felt252>,
    leaves_len: u64,
}

#[generate_trait]
pub impl MerkleImpl of MerkleTrait {
    fn new(data: Array<Card>, salt: Array<felt252>) -> MerkleState {
        let tree = _build_tree_v2(data.clone(), salt);
        MerkleState { tree, leaves_len: data.len().into() }
    }

    fn get_root(ref self: MerkleState) -> felt252 {
        let tree_len = self.tree.len();
        assert(tree_len > 0, 'TREE IS EMPTY');
        *self.tree.at(tree_len - 1)
    }

    fn generate_proof_v2(ref self: MerkleState, mut index: u64) -> Array<felt252> {
        let data_length = self.leaves_len;
        let mut proof: Array<felt252> = ArrayTrait::new();
        let mut offset = 0;
        let mut current_nodes_lvl_len = if data_length % 2 != 0 {
            data_length + 1
        } else {
            data_length
        };

        while current_nodes_lvl_len > 1 {
            let sibling_index = if index % 2 == 0 {
                offset + index + 1
            } else {
                offset + index - 1
            };
            proof.append(*self.tree.at(sibling_index.try_into().unwrap()));
            offset += current_nodes_lvl_len;
            current_nodes_lvl_len /= 2;
            index /= 2;
            if current_nodes_lvl_len > 1 && current_nodes_lvl_len % 2 != 0 {
                current_nodes_lvl_len += 1;
            };
        }
        proof
    }

    fn generate_proof_v1(mut leaves: Array<felt252>, index: u32) -> Array<felt252> {
        let mut proof: Array<felt252> = array![];

        // add a null leaf if leaves.len is odd, to make it even.
        if leaves.len() % 2 != 0 {
            leaves.append(0);
        }
        compute_proof(leaves, index, ref proof);
        proof
    }

    // TEST BOTH VERIFICATIONS.
    fn verify_v1(root: felt252, mut leaf: felt252, mut proof: Span<felt252>) -> bool {
        for proof_element in proof {
            // Compute the hash of the current node and the current element of the proof.
            // We need to check if the current node is smaller than the current element of the
            // proof.
            // If it is, we need to swap the order of the hash.
            let leaf_ref: u256 = leaf.into();
            leaf =
                if leaf_ref < (*proof_element).into() {
                    hash(leaf, *proof_element)
                } else {
                    hash(*proof_element, leaf)
                };
        }
        leaf == root
    }

    fn verify_v2(
        mut proof: Array<felt252>, root: felt252, leaf: felt252, mut index: usize,
    ) -> bool {
        let mut current_hash = leaf;

        while let Option::Some(proof_value) = proof.pop_front() {
            current_hash =
                if index % 2 == 0 {
                    hash(current_hash, proof_value)
                    // PoseidonTrait::new().update_with((current_hash, proof_value)).finalize()
                } else {
                    hash(proof_value, current_hash)
                    // PoseidonTrait::new().update_with((proof_value, current_hash)).finalize()
                };

            index /= 2;
        }

        current_hash == root
    }
}

fn compute_proof(mut nodes: Array<felt252>, index: u32, ref proof: Array<felt252>) {
    if index % 2 == 0 {
        proof.append(*nodes.at(index + 1));
    } else {
        proof.append(*nodes.at(index - 1));
    }
    // Break if we have reached the top of the tree (next_level would be root)
    if nodes.len() == 2 {
        return;
    }
    // Compute next level
    let next_level: Array<felt252> = get_next_level(nodes.span());

    compute_proof(next_level, index / 2, ref proof)
}

fn get_next_level(mut nodes: Span<felt252>) -> Array<felt252> {
    let mut next_level: Array<felt252> = array![];
    while let Option::Some(left) = nodes.pop_front() {
        let right = *nodes.pop_front().expect('Index out of bounds');
        let node = if Into::<felt252, u256>::into(*left) < right.into() {
            hash(*left, right)
        } else {
            hash(right, *left)
        };
        next_level.append(node);
    }
    next_level
}

fn _build_tree_v2(data: Array<Card>, salt: Array<felt252>) -> Array<felt252> {
    let data_len = data.len();
    let mut _hashes: Array<felt252> = ArrayTrait::new();
    let mut last_element = Option::None;

    if data_len > 0 && (data_len % 2) != 0 {
        last_element = Option::Some(data.at(data_len - 1).clone());
    }

    for mut value in data {
        _hashes.append(value.hash(salt.clone()));
    }

    let mut current_nodes_lvl_len = data_len;
    let mut hashes_offset = 0;

    // if data_len is uneven, add the last element to the hashes array
    match last_element {
        Option::Some(mut value) => {
            _hashes.append(value.hash(salt));
            current_nodes_lvl_len += 1;
        },
        Option::None => {},
    }

    while current_nodes_lvl_len > 0 {
        let mut i = 0;
        while i < current_nodes_lvl_len - 1 {
            let left_elem = *_hashes.at(hashes_offset + i);
            let right_elem = *_hashes.at(hashes_offset + i + 1);

            // let hash = PoseidonTrait::new().update_with((left_elem, right_elem)).finalize();
            let hash = hash(left_elem, right_elem);
            _hashes.append(hash);

            i += 2;
        }

        hashes_offset += current_nodes_lvl_len;
        current_nodes_lvl_len /= 2;
        if current_nodes_lvl_len > 1 && current_nodes_lvl_len % 2 != 0 {
            // duplicate last element of hashes array if current_nodes_lvl_len is uneven
            let last_elem = *_hashes.at(_hashes.len() - 1);
            _hashes.append(last_elem);
            current_nodes_lvl_len += 1;
        };
    }

    _hashes
}

fn hash(data1: felt252, data2: felt252) -> felt252 {
    let (hash, _, _) = hades_permutation(data1, data2, 2);
    hash
}

#[cfg(test)]
pub mod Tests {
    use crate::models::card::{Card, CardTrait, Royals, Suits};
    use super::{MerkleState, MerkleTrait};

    fn salt() -> Array<felt252> {
        array!['Salt1', 'Salt2', 'Salt3']
    }

    fn card(suit: u8, value: u16) -> Card {
        Card { suit, value }
    }

    fn default_hand() -> Array<Card> {
        let mut hand: Array<Card> = array![];
        hand.append(card(Suits::CLUBS, Royals::ACE));
        hand.append(card(Suits::CLUBS, 4));
        hand.append(card(Suits::CLUBS, 5));
        hand
    }

    #[test]
    fn test_merkle_generate_root_and_verification_success() {
        // root: 3265258184025689748944567234307789604284324313859921054492400796521367996981
        let cards = default_hand();
        let mut merkle_state = MerkleTrait::new(cards.clone(), salt());
        let root = merkle_state.get_root();
        println!("Root of cards: {}", root);

        let mut leaves: Array<felt252> = array![];
        for i in 0..cards.len() {
            let mut card = *cards.at(i);
            leaves.append(card.hash(salt()));
        }

        let proof = merkle_state.generate_proof_v2(0);

        // let's verify that ACE of CLUBS is in this root, using this proof.
        let verified = MerkleTrait::verify_v2(proof, root, *leaves.at(0), 0);
        assert(verified, 'V2 VERIFICATION FAILED');
    }

    #[test]
    fn test_merkle_verification_failure_on_invalid_proof() {
        // root of the last test
        let cards = default_hand();
        let root: felt252 =
            3265258184025689748944567234307789604284324313859921054492400796521367996981;
        // proof of ACE of CLUBS on the last test.
        let proof = array![
            3044331186771646128379142839638382346410288533857569651221843248057032875529,
            1482025689999262917428523866462686644709767517261250894155030474966436422230,
        ];
        let mut card0 = *cards.at(0);
        let leaf0 = card0.hash(salt());
        let verified = MerkleTrait::verify_v2(proof, root, leaf0, 0);
        assert(verified, 'SHOULD VERIFY.');
        let proof = array![
            3044331186771646128379142839638382346410288533857569651221843248057032875529 + 1,
            1482025689999262917428523866462686644709767517261250894155030474966436422230,
        ];
        let verified = MerkleTrait::verify_v2(proof, root, leaf0, 0);
        assert(!verified, 'SHOULD NOT VERIFY');
    }
}
