# Binary Prediction Market

A gas-optimized on-chain binary prediction market where users bet on Yes or No outcomes.  
The contract supports multiple markets, proportional payouts, cancellations, and secure claims.

## Features

- Multiple markets managed by the owner
- Users place bets on side 0 (No) or 1 (Yes)
- Payouts are proportional to losing pool share
- Market cancellation with full refunds
- Reentrancy-safe claim process
- Gas-optimized storage and logic

## How It Works

### 1. Market Creation
The owner creates a market by setting a question and betting duration.

### 2. Betting Phase
Users bet on Yes or No by sending ETH.  
Betting closes at the market deadline.

### 3. Resolution
The owner declares the outcome after the deadline.


### 5. Cancelled Markets
All users receive refunds if the owner cancels an open market.

## Security

- Non-reentrant claim function
- Checks-effects-interactions pattern
- Uses OpenZeppelin Ownable and ReentrancyGuard


### 4. Claim Rewards
Winners receive:
