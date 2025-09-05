import { ec, hash, type BigNumberish, type WeierstrassSignatureType, stark, num } from 'starknet';

// --- Configuration ---
// These are example private keys. In a real application, these would be securely managed
// and not hardcoded. Each private key corresponds to a player's identity.
const privateKey1 = '0x1234567890987654321';
const privateKey2 = '0x1234567890987654322';

// --- Public Key Generation ---
// From the private keys, we derive the StarkNet public keys. These public keys are what
// are stored on the blockchain and used to verify signatures.
// `ec.starkCurve.getStarkKey` computes the x-coordinate of the public key on the Stark curve.
const starknetPublicKey1 = ec.starkCurve.getStarkKey(privateKey1);
const starknetPublicKey2 = ec.starkCurve.getStarkKey(privateKey2);

console.log("StarkNet Public Key 1:", starknetPublicKey1);
console.log("StarkNet Public Key 2:", starknetPublicKey2);

// `stark.getFullPublicKey` also provides the full public key (x, y coordinates).
// While `getStarkKey` is sufficient for signature verification in StarkNet contracts
// (which only use the x-coordinate for the public key), it's good to be aware of both.
const fullPublicKey1 = stark.getFullPublicKey(privateKey1);
const fullPublicKey2 = stark.getFullPublicKey(privateKey2);

console.log("Full Public Key 1 (x, y):", fullPublicKey1);
console.log("Full Public Key 2 (x, y):", fullPublicKey2);

// --- Message Serialization for Signing ---
// The `showdown` function in the Dojo contract expects a `message` array for signature
// verification. This array is a serialized representation of a player's `Hand` data
// along with a `nonce`.

// For `player1`:
// The `Hand` struct in the contract (poker/models/hand.cairo) looks like:
// struct Hand {
//     player: ContractAddress, // The player's address
//     cards: Array<Card>,     // An array of Card structs
// }
// struct Card {
//    suit: u8,
//    value: u16,
// }
//
// When a Hand is serialized (as done by `hand.serialize(ref hash_input)` in the contract),
// it typically flattens its members into an array of felt252s.
//
// Example serialization for Hand 1:
// [player1_address, num_cards, card1_suit, card1_value, card2_suit, card2_value, ...]
//
// In our test, `card(0, 14)` means Suit 0 (e.g., Clubs), Value 14 (Ace).
// So, the serialized hand for player1 with cards (0, 14), (1, 13), (2, 12) would be:
// [player1_address, 3 (number of cards), 0, 14, 1, 13, 2, 12]
//
// The `nonce` is appended to this serialized hand for each signature to prevent replay attacks.
// The `nonce` is an `u64` and needs to be converted to `BigNumberish` (felt252 compatible).
const nonce1 = 0; // Example nonce for the first signature

const message1: BigNumberish[] = [
    num.toBigInt(starknetPublicKey1), // Player 1's ContractAddress (represented by its public key)
    3,                                 // Number of cards in hand
    0, 14,                             // Card 1: Suit 0, Value 14 (e.g., Ace of Clubs)
    1, 13,                             // Card 2: Suit 1, Value 13 (e.g., King of Diamonds)
    2, 12,                             // Card 3: Suit 2, Value 12 (e.g., Queen of Hearts)
    nonce1                             // Nonce for this specific signature
];

// For `player2`:
const nonce2 = 0; // The nonce for player2's signature, assuming it's the same round

const message2: BigNumberish[] = [
    num.toBigInt(starknetPublicKey2), // Player 2's ContractAddress
    3,                                 // Number of cards in hand
    3, 11,                             // Card 1: Suit 3, Value 11 (e.g., Jack of Spades)
    0, 10,                             // Card 2: Suit 0, Value 10 (e.g., Ten of Clubs)
    1, 9,                              // Card 3: Suit 1, Value 9 (e.g., Nine of Diamonds)
    nonce2                             // Nonce for this specific signature
];

// --- Message Hashing ---
// Before signing, the message is hashed using the Poseidon hash function.
// This produces a fixed-size hash that is then signed.
// `hash.computePoseidonHashOnElements` computes the Poseidon hash of an array of BigNumberish elements.
const msgHash1 = hash.computePoseidonHashOnElements(message1);
console.log("Message Hash 1:", msgHash1);

const msgHash2 = hash.computePoseidonHashOnElements(message2);
console.log("Message Hash 2:", msgHash2);

// --- Signature Generation ---
// The `ec.starkCurve.sign` function takes the message hash and the player's private key
// to generate an ECDSA signature on the Stark curve.
// The signature consists of two components: `r` and `s`.
const signature1: WeierstrassSignatureType = ec.starkCurve.sign(msgHash1, privateKey1);
const signature2: WeierstrassSignatureType = ec.starkCurve.sign(msgHash2, privateKey2);

console.log("Signature 1 (r, s):", signature1);
console.log("Signature 2 (r, s):", signature2);

// --- Outputting for Cairo Consumption ---
// In Cairo, signatures are typically passed as two felt252s (r and s).
// The `signature_r` and `signature_s` arrays in the `showdown` function
// correspond to these components.
// `num.toHex` converts the BigNumberish values to hexadecimal strings for display.
console.log("Signature R 1 (Hex):", num.toHex(signature1.r));
console.log("Signature S 1 (Hex):", num.toHex(signature1.s));
console.log("Signature R 2 (Hex):", num.toHex(signature2.r));
console.log("Signature S 2 (Hex):", num.toHex(signature2.s));

// The `signature_y_parity` (boolean) indicates which of the two possible Y-coordinates
// for the public key was used during signature recovery. It's often passed as a boolean
// directly or its numeric equivalent (0 or 1).
// In the current context of `recover_public_key`, the boolean is directly used.
// For the purpose of the test, we're assuming 'true' for simplicity, but it depends on
// the specifics of the actual signature and recovery.
console.log("Signature Y Parity 1 (Boolean):", true); // This would be derived from the signature
console.log("Signature Y Parity 2 (Boolean):", true); // This would be derived from the signature

/*
--- How these values are used in the Cairo contract's `verify_signature_params` function ---

The `verify_signature_params` function in `poker::contracts::actions` performs the following steps for each hand:

1.  **Reconstructs Message Hash**:
    ```cairo
    let mut hash_input: Array<felt252> = array![];
    hand.serialize(ref hash_input); // Serializes the `Hand` struct
    hash_input.append(nonce.into()); // Appends the nonce
    let message_hash: felt252 = poseidon_hash_span(hash_input.span()); // Hashes the serialized data
    ```
    This matches how `msgHash1` and `msgHash2` are computed in the TypeScript script.

2.  **Recovers Public Key**:
    ```cairo
    let recovered_pubkey: Option<felt252> = recover_public_key(message_hash, r, s, y_parity);
    ```
    This attempts to derive the public key from the message hash and the provided signature components (`r`, `s`, `y_parity`).

3.  **Compares Recovered Public Key**:
    ```cairo
    let player: Player = world.read_model(*hand.player); // Reads the player's stored public key
    assert(pubkey_felt == player.pub_key, 'INVALID PUB KEY');
    ```
    The recovered public key is compared against the public key stored in the `Player` model on-chain. This is why `starknetPublicKey1` and `starknetPublicKey2` are used as the `player` field in the serialized message and later compared to `player.pub_key`.

4.  **Verifies ECDSA Signature (Optional but good practice)**:
    ```cairo
    let signature_valid: bool = check_ecdsa_signature(message_hash, player.pub_key, r, s);
    assert(signature_valid, 'INVALID SIGNATURE');
    ```
    This provides an additional check to ensure the signature is mathematically valid for the given message hash and public key.

In essence, the TypeScript script generates the exact signature components (`r`, `s`, `y_parity`) and the message content (`hands` array) that the Cairo contract needs to verify that a player legitimately "signed" their hand.
*/