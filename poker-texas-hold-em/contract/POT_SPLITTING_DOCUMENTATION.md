# Pot Splitting Implementation Documentation

## Overview

This document describes the implementation of fair pot splitting logic for the poker game, including support for kicker cards, multiple pots (main pot vs side pots), and casino cut collection.

## Author
@truthixify

## Key Features

### 1. Multi-Pot Support
- **Main Pot**: Available to all players who participated in betting
- **Side Pots**: Created when players go all-in with different amounts
- **Pot Eligibility**: Players have an `eligible_pots` field indicating how many pots they can win

### 2. Kicker-Based Splitting
- **Kicker Differentiation**: When players have equal hand ranks, kickers determine the winner
- **Perfect Ties**: When hands and kickers are identical, pots are split evenly
- **Configurable**: Controlled by `game_params.kicker_split` boolean

### 3. Casino Cut Collection
- **20% Cut**: Collected from non-winning players who resolved hands
- **Winner Exemption**: Winners pay no casino cut
- **Tracking**: `CasinoFunds` model tracks total collected per game

## Core Functions

### `split_pots_with_kickers`
Main function that orchestrates pot splitting based on winning hands and kicker cards.

**Parameters:**
- `game`: Mutable reference to game state
- `winning_hands`: Array of hands that won (from `compare_hands`)
- `kicker_cards`: Kicker cards for tie-breaking (from `compare_hands`)

**Logic Flow:**
1. Validate parameters
2. Handle no-winners scenario (kicker_split=false)
3. Process each pot individually:
   - Find eligible players for the pot
   - Filter winners among eligible players
   - Split pot based on winner count and kicker presence
4. Collect casino cut from non-winners

### Helper Functions

#### `_get_eligible_players_for_pot`
Determines which players are eligible for a specific pot based on their `eligible_pots` field.

#### `_filter_winners_for_pot`
Filters winning hands to only include those eligible for the specific pot.

#### `_split_pot_among_eligible`
Splits a pot evenly among all eligible players (used when no clear winners).

#### `_award_pot_to_winner`
Awards entire pot to a single winner.

#### `_split_pot_among_winners`
Splits pot evenly among multiple winners (perfect tie scenario).

#### `_collect_casino_cut`
Collects 20% cut from non-winning players and updates casino funds.

## Pot Splitting Scenarios

### Scenario 1: Single Winner
- **Condition**: One player has the best hand
- **Action**: Winner receives all pots they're eligible for
- **Casino Cut**: Collected from all other players

### Scenario 2: Multiple Winners with Kickers
- **Condition**: Multiple players have same hand rank, but kickers differentiate
- **Action**: Player with highest kicker wins entire pot
- **Casino Cut**: Collected from non-winners

### Scenario 3: Perfect Tie
- **Condition**: Multiple players have identical hands and kickers
- **Action**: Pot split evenly among tied players
- **Casino Cut**: No cut collected (no clear losers)

### Scenario 4: No Winners (kicker_split=false)
- **Condition**: `game_params.kicker_split` is false and hands are tied
- **Action**: All pots split evenly among eligible players
- **Casino Cut**: No cut collected

### Scenario 5: Complex Multi-Pot
- **Condition**: Multiple pots with different player eligibilities
- **Action**: Each pot processed independently based on eligible winners
- **Example**: 
  - Main pot: All players eligible, Player A wins
  - Side pot 1: Players A & B eligible, Player A wins
  - Side pot 2: Only Player A eligible, Player A wins automatically

## Data Models

### CasinoFunds
```cairo
struct CasinoFunds {
    id: u64,                    // Game ID
    total_collected: u256,      // Total amount collected
    last_collection_round: u64, // Last round when collection occurred
}
```

### Events

#### PotSplit
```cairo
struct PotSplit {
    game_id: u64,
    pot_index: u32,
    winners: Array<ContractAddress>,
    amounts: Array<u256>,
    total_pot: u256,
}
```

#### CasinoCollection
```cairo
struct CasinoCollection {
    game_id: u64,
    amount_collected: u256,
    round: u64,
    from_player: ContractAddress,
}
```

## Integration with Existing Code

### Round Resolution Integration
The pot splitting logic is integrated into the `_resolve_round_v2` function:

```cairo
let (winning_hands, _, kicker_cards) = self._extract_winner(game_id, community_cards, hands);

// Convert winning hands span to array for pot splitting
let mut winning_hands_array: Array<Hand> = array![];
for i in 0..winning_hands.len() {
    winning_hands_array.append(*winning_hands.at(i));
}

// Split pots based on winners and kicker cards
self.split_pots_with_kickers(ref game, winning_hands_array.clone(), kicker_cards);
```

### Hand Comparison Integration
The implementation relies on the existing `compare_hands` function which returns:
- `Span<Hand>`: Winning hands
- `HandRank`: Rank of winning hands
- `Span<Card>`: Kicker cards (if any)

## Testing

### Unit Tests (`test_pot_splitting.cairo`)
- Single winner scenarios
- Multiple winner scenarios
- Kicker differentiation
- Casino cut collection
- Edge cases (empty pots, no winners)

### Integration Tests (`test_pot_splitting_integration.cairo`)
- Complete game flow with pot splitting
- Realistic betting scenarios
- Multi-pot creation and resolution
- Edge cases in game flow

## Error Handling

### Validation
- Ensures pots exist before splitting
- Validates winning hands belong to game players
- Checks player eligibility for pots

### Edge Cases
- Empty pots are skipped
- Players with insufficient chips for casino cut are handled gracefully
- Zero-length winner arrays are handled appropriately

## Performance Considerations

### Reusable Functions
- `_validate_pot_split_params`: Centralized parameter validation
- `_calculate_casino_cut`: Centralized cut calculation
- `_update_player_chips_and_emit`: Centralized chip updates

### Efficient Loops
- Single pass through players for eligibility checks
- Minimal array operations
- Early returns for edge cases

## Future Enhancements

### Potential Improvements
1. **Configurable Casino Cut**: Make the 20% rate configurable per game
2. **Partial Cut Collection**: Handle cases where players have insufficient chips
3. **Advanced Pot Types**: Support for more complex pot structures
4. **Audit Trail**: Enhanced logging for pot splitting decisions
5. **Gas Optimization**: Further optimize for large player counts

### Backwards Compatibility
The implementation maintains full backwards compatibility with existing game logic and only adds new functionality without breaking existing features.

## Security Considerations

### Validation
- All inputs are validated before processing
- Player eligibility is strictly enforced
- Pot amounts are verified before distribution

### Precision
- Uses u256 for all chip calculations to prevent overflow
- Handles remainder distribution fairly
- Ensures total pot amounts are preserved

### Access Control
- Only callable from within the contract
- Relies on existing game state validation
- Maintains player ownership verification

## Conclusion

This implementation provides a comprehensive, fair, and efficient pot splitting system that handles all major poker scenarios while maintaining code quality, testability, and performance. The modular design allows for easy maintenance and future enhancements while ensuring robust operation in all game conditions.