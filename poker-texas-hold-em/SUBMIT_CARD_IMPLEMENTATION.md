# Submit Card Implementation

## Overview

This document describes the implementation of the `submit_card` functionality for the poker game contract. The implementation follows the specifications provided and includes card verification using Merkle proofs, automatic round resolution, and comprehensive testing.

## Implementation Details

### Files Modified/Created

1. **`contract/src/systems/interface.cairo`**
   - Added `submit_card` function to the `IActions` interface

2. **`contract/src/systems/actions.cairo`**
   - Implemented `submit_card` function in `ActionsImpl`
   - Added `verify_card` function to `InternalTrait`
   - Added `_verify_single_card` helper function
   - Added `_increment_submission_count` helper function
   - Updated imports to include `RoundSubmissions`

3. **`contract/src/models/base.cairo`**
   - Added `RoundSubmissions` model to track card submissions per round

4. **`contract/src/tests/test_submit_card.cairo`**
   - Comprehensive test suite for the submit_card functionality

## Function Specifications

### `submit_card`

```cairo
fn submit_card(
    ref self: ContractState,
    cards: Array<Card>,
    deck_proof: Array<felt252>,
    dealt_cards_proof: Array<felt252>,
    staked_amount: u256,
)
```

**Purpose**: Allows players to submit their cards with cryptographic proofs for verification.

**Workflow**:
1. Validates that the player is in a round and has finished playing
2. Ensures the player has sufficient chips for staking
3. Verifies the submitted cards against the game's Merkle roots
4. If verification succeeds:
   - Stores the hand on-chain
   - Increments the submission count
   - Automatically resolves the round when all players have submitted
5. If verification fails:
   - Deducts the staked amount from the player
   - Adds the staked amount to the game pot

### `verify_card` (InternalTrait)

```cairo
fn verify_card(
    self: @ContractState,
    cards: Array<Card>,
    deck_proof: Array<felt252>,
    dealt_cards_proof: Array<felt252>,
    deck_root: felt252,
    dealt_cards_root: felt252,
) -> bool
```

**Purpose**: Verifies that submitted cards are valid against both the deck state and dealt cards state.

**Features**:
- Verifies each card against both Merkle roots (deck and dealt cards)
- Uses predefined salt arrays for consistent hashing
- Returns `false` for empty card arrays or verification failures
- Implements the specification requirement for dual root verification

### `RoundSubmissions` Model

```cairo
#[derive(Serde, Copy, Drop, PartialEq)]
#[dojo::model]
pub struct RoundSubmissions {
    #[key]
    pub game_id: u64,
    #[key]
    pub round_number: u8,
    pub submitted_count: u32,
    pub total_players: u32,
}
```

**Purpose**: Tracks the number of card submissions per round to enable automatic round resolution.

## Key Features Implemented

### 1. Player Validation
- Ensures player is locked into a game
- Verifies player is actively in the current round
- Checks that the game is in progress and round is active

### 2. Staking Mechanism
- Requires players to stake an amount when submitting cards
- Deducts staked amount on verification failure
- Adds failed stakes to the game pot

### 3. Dual Merkle Verification
- Verifies cards against the original deck root
- Verifies cards against the dealt cards root
- Uses consistent salt arrays for hashing

### 4. Automatic Round Resolution
- Tracks submission count per round
- Automatically calls `resolve_round` when all players have submitted
- Prevents duplicate submissions through game state management

### 5. Comprehensive Error Handling
- Validates player state and game state
- Handles insufficient chips gracefully
- Provides clear error messages for debugging

## Security Considerations

### 1. Merkle Proof Verification
- Uses the existing `MerkleTrait::verify_v2` function for cryptographic verification
- Requires proofs for both deck state and dealt cards state
- Prevents card reuse and ensures cards were legitimately dealt

### 2. Staking Mechanism
- Prevents spam submissions by requiring chip stakes
- Economically disincentivizes invalid submissions
- Redistributes failed stakes to the game pot

### 3. State Validation
- Comprehensive validation of player and game states
- Prevents submissions outside of active rounds
- Ensures only legitimate players can submit

## Testing

The implementation includes comprehensive tests covering:

1. **Successful Submissions**: Valid cards with correct proofs
2. **Validation Failures**: Player not in round, insufficient chips
3. **Verification Failures**: Invalid proofs, empty cards
4. **Multiple Players**: Submission tracking and automatic resolution
5. **Edge Cases**: Empty card arrays, invalid game states

### Test Coverage

- `test_submit_card_success`: Tests successful card submission
- `test_submit_card_player_not_in_round`: Tests validation failure
- `test_submit_card_insufficient_chips`: Tests insufficient chip handling
- `test_submit_card_verification_failure`: Tests failed verification
- `test_multiple_players_submit_cards`: Tests multi-player scenarios
- `test_submit_card_empty_cards`: Tests empty card array handling

## Future Enhancements

### 1. Card Signing
The specification mentions future implementation of card signing. This could be added by:
- Extending the `submit_card` function to accept signatures
- Adding signature verification before Merkle proof verification
- Creating additional security layers for card authenticity

### 2. Proof Aggregation
The specification mentions potential future aggregation of proofs. This could involve:
- Combining deck and dealt card proofs into a single proof
- Optimizing verification performance
- Reducing transaction size and gas costs

### 3. Enhanced Staking
- Dynamic staking amounts based on game parameters
- Partial stake recovery for near-valid submissions
- Stake redistribution mechanisms

## Code Quality

The implementation follows the specified requirements:
- **Strongly typed**: All functions use explicit types
- **Professional documentation**: Comprehensive comments and documentation
- **Trait usage**: Leverages existing traits and implements new ones as needed
- **No code repetition**: Helper functions extract common functionality
- **Author attribution**: All functions include `@AugmentAgent` attribution

## Conclusion

This implementation provides a robust, secure, and efficient card submission system that meets all specified requirements. The dual Merkle verification ensures card authenticity, the staking mechanism prevents abuse, and the automatic round resolution streamlines gameplay. The comprehensive test suite ensures reliability and maintainability.
