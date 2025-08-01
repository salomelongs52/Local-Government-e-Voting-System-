# 🗳️ Local Government e-Voting System 🏛️

A decentralized, tamper-resistant voting platform built on Stacks blockchain for local governance initiatives.

## 🌟 Overview

This smart contract enables secure electronic voting for:
- 🏙️ Town/city councils
- 🏫 University student bodies
- 🏢 Cooperatives and community organizations
- 🏘️ Neighborhood associations

## ✨ Features

- **🔒 Secure Voter Registration**: Only registered voters can participate
- **📝 Proposal Creation**: Any registered voter can create proposals
- **🗳️ Transparent Voting**: All votes are recorded on the blockchain
- **🗺️ District Management**: Organize voters by geographic or organizational districts
- **⏱️ Time-bound Voting**: Proposals have clear start and end blocks
- **🔍 Result Verification**: Vote tallies are publicly verifiable

## 📋 Contract Functions

### Voter Management
- `register-voter`: Register as a voter in a specific district
- `get-voter`: View voter registration information
- `get-voter-district`: Check which district a voter belongs to

### Proposal Management
- `create-proposal`: Create a new voting proposal
- `get-proposal`: View details of a specific proposal
- `get-proposal-count`: Get the total number of proposals
- `close-proposal`: End voting for a proposal

### Voting
- `vote`: Cast a vote (yes/no/abstain) on a proposal
- `get-vote`: Check how a specific voter voted on a proposal

### District Management
- `create-district`: Create a new voting district
- `deactivate-district`: Disable a voting district
- `get-district`: View district information

### Administration
- `transfer-ownership`: Transfer contract ownership to a new administrator

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet)
- [Stacks Wallet](https://www.hiro.so/wallet)

### Deployment

1. Clone this repository
2. Install Clarinet if you haven't already:
```bash
curl -sS https://install.clarinet.sh | sh
```

3. Initialize a new Clarinet project:
```bash
clarinet new my-voting-system && cd my-voting-system
```

4. Replace the default contract with this contract:
```bash
cp /path/to/Government-E-Voting-System.clar contracts/
```

5. Test the contract locally:
```bash
clarinet console
```

6. Deploy to testnet or mainnet using Clarinet's deployment commands

## 📊 Example Usage

### Register as a voter
```clarity
(contract-call? .government-e-voting-system register-voter "downtown")
```

### Create a proposal
```clarity
(contract-call? .government-e-voting-system create-proposal "New Park" "Build a community park on Main Street" u1000)
```

### Vote on a proposal
```clarity
(contract-call? .government-e-voting-system vote u0 "yes")
```

### Check proposal results
```clarity
(contract-call? .government-e-voting-system get-proposal u0)
```

## 🔐 Security Considerations

- The contract owner has special privileges
- Votes are public on the blockchain
- Once cast, votes cannot be changed
- Closed proposals cannot be reopened

## 📜 License

This project is licensed under the MIT License.
```