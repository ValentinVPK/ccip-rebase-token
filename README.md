# Cross-Chain Rebase Token

A Solidity implementation of a rebase token protocol featuring cross-chain compatibility via Chainlink CCIP (Cross-Chain Interoperability Protocol).

## Overview

This protocol allows users to deposit assets into a vault and receive rebase tokens that dynamically represent their underlying balance. The rebase token is designed with these key features:

- **Dynamic Balances**: The `balanceOf` function shows balances that increase linearly with time
- **Individual Interest Rates**: Each user's interest rate is based on the global protocol interest rate at the time of deposit
- **Cross-Chain Compatibility**: Tokens can be bridged across different blockchain networks while preserving user-specific interest rates
- **Decreasing Global Rate**: The global interest rate can only decrease over time, incentivizing early adopters

## Architecture

The protocol consists of three main components:

### 1. RebaseToken.sol

The core ERC20-compatible token that implements rebasing functionality:

- Tracks user-specific interest rates
- Calculates accrued interest based on time elapsed
- Maintains principle balances separately from interest
- Mints additional tokens to users when they interact with the protocol

### 2. Vault.sol

Manages deposits and withdrawals:

- Accepts user deposits and mints rebase tokens in return
- Handles redemptions by burning tokens and returning assets to users
- Captures the global interest rate at time of deposit

### 3. RebaseTokenPool.sol

Enables cross-chain transfers via Chainlink CCIP:

- Handles token locking/burning on the source chain
- Manages token minting/releasing on the destination chain
- Preserves user-specific interest rates across chain boundaries

## Libraries and Dependencies

This project leverages several key libraries and frameworks:

### Core Dependencies

- **OpenZeppelin Contracts**: Used for implementing standard token functionality (ERC20), access control, and ownership management
  - ERC20: Base implementation for the rebase token
  - Ownable: For restricted admin functions
  - AccessControl: For role-based permissions

### Cross-Chain Infrastructure

- **Chainlink CCIP**: Cross-Chain Interoperability Protocol for secure bridging between networks
  - TokenPool: Base implementation for cross-chain token pools
  - IRouterClient: Interface for cross-chain message routing
  - Client: Library for constructing cross-chain messages

### Development and Testing

- **Forge Standard Library (forge-std)**: Utilities for testing and script development
  - Script: Base contract for deployment scripts
  - Test: Framework for writing and running tests
  - Console: Utilities for debugging

### Local Testing Infrastructure

- **Chainlink Local**: Testing utilities for simulating Chainlink services locally
  - CCIPLocalSimulatorFork: For testing cross-chain functionality in a local environment

## Key Features

### Rebasing Mechanism

- Interest accrues linearly with time
- Users receive interest when performing any action (minting, burning, transferring, or bridging)
- No need for manual claims - interest is automatically added to user balances

### Interest Rate Model

- Global interest rate is set by protocol governance
- Each user's individual rate is locked in at time of deposit
- Protocol incentivizes early adoption through decreasing rate model

### Cross-Chain Compatibility

- Seamless bridging across chains via Chainlink CCIP
- User interest rates are preserved during cross-chain transfers
- Native support for the CCIP token pool standard

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Blockchain wallet and testnet ETH on supported networks

### Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/cross-chain-rebase-token.git
cd cross-chain-rebase-token
```

2. Install dependencies:

```bash
forge install
```

3. Compile the contracts:

```bash
forge build
```

### Testing

Run the test suite:

```bash
forge test
```

### Deployment

Deploy the contracts to a supported network:

```bash
forge script script/Deploy.s.sol --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY> --broadcast
```

## Usage Examples

### Depositing into the Vault

```solidity
// Send ETH to the vault and receive rebase tokens
vault.deposit{value: 1 ether}();
```

### Redeeming Tokens

```solidity
// Redeem a specific amount
vault.redeem(100000000000000000);

// Redeem all tokens
vault.redeem(type(uint256).max);
```

### Bridging Tokens

The tokens can be bridged across supported chains using Chainlink CCIP. User-specific interest rates are preserved during the bridging process.

## License

This project is licensed under the MIT License.

## Documentation

For detailed technical documentation, see the following docs:

- [Chainlink CCIP](./Chainlink_CCIP.md)
- [Cross Chain Token Standard](./Cross_Chain_Token_Standard.md)
- [Bridge Documentation](./bridge.md)
- [Access Control](./access-control.md)
