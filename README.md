# 🆔 Decentralized Identity for Refugees

A blockchain-based self-sovereign identity system built on Stacks to provide verifiable digital identities for refugees and displaced persons worldwide.

## 🎯 Problem & Solution

**Problem**: Refugees often lack verifiable identification documents, making it difficult to access essential services, employment, and humanitarian aid.

**Solution**: A decentralized identity system stored on the Bitcoin blockchain via Stacks, enabling refugees to maintain control over their identity data regardless of their physical location.

## ✨ Features

- 🔐 **Self-Sovereign Identity**: Complete control over personal data
- 🛡️ **Verification System**: Multi-level identity verification by authorized entities
- 🔄 **Recovery Mechanism**: Account recovery through trusted addresses
- 👥 **Guardian Support**: Trusted guardians can assist with identity management
- 🔒 **Encrypted Data Storage**: Secure storage of sensitive information
- ⚡ **Bitcoin Security**: Leverages Bitcoin's security through Stacks blockchain

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Stacks CLI](https://docs.stacks.co/docs/write-smart-contracts/cli-wallet-quickstart) for interactions

### Installation

1. Clone the repository
```bash
git clone https://github.com/yourusername/decentralized-identity-refugees
cd decentralized-identity-refugees
```

2. Check the project
```bash
clarinet check
```

3. Run tests
```bash
clarinet test
```

## 📖 Usage

### 🆕 Creating an Identity

```bash
clarinet console
::set_tx_sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
::contract_call .Decentrlized-Identity-Refugees create-identity 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG
```

### 📝 Adding Identity Data

```bash
::contract_call .Decentrlized-Identity-Refugees update-identity-data u1 "name" "John Doe" false
::contract_call .Decentrlized-Identity-Refugees update-identity-data u1 "nationality" "Syrian" false
```

### ✅ Verifying Identity

First, authorize a verifier (contract owner only):
```bash
::contract_call .Decentrlized-Identity-Refugees authorize-verifier 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5 (list "government-id" "refugee-status")
```

Then verify an identity:
```bash
::set_tx_sender ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5
::contract_call .Decentrlized-Identity-Refugees verify-identity u1 "government-id" 0x...signature...
```

### 🔍 Reading Identity Information

```bash
::contract_call .Decentrlized-Identity-Refugees get-identity u1
::contract_call .Decentrlized-Identity-Refugees get-identity-data u1 "name"
::contract_call .Decentrlized-Identity-Refugees is-verification-valid u1 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5
```

## 🏗️ Contract Structure

### Core Functions

- `create-identity` - Create a new decentralized identity
- `update-identity-data` - Add/update identity information
- `verify-identity` - Verify identity by authorized entities
- `transfer-identity` - Transfer identity ownership
- `initiate-recovery` / `confirm-recovery` - Account recovery process

### Management Functions

- `authorize-verifier` - Add authorized verification entities
- `revoke-verifier` - Remove verifier authorization
- `add-guardian` - Add trusted guardians

### Read-Only Functions

- `get-identity` - Retrieve identity information
- `get-identity-data` - Get specific data fields
- `get-verification` - Check verification status
- `is-verification-valid` - Validate verification expiry

## 💰 Fees

- **Identity Creation**: 1 STX
- **Verification**: 0.5 STX (paid by identity owner to verifier)

## 🔒 Security Features

- **Multi-signature Recovery**: 24-block waiting period for recovery
- **Verification Expiry**: Verifications expire after ~1 year (52,560 blocks)
- **Authorization Controls**: Only authorized entities can verify identities
- **Owner Controls**: Only identity owners can update their data

## 🤝 Contributing

We welcome contributions! Please feel free to submit issues and pull requests.

## 📄 License

This project is open source and available under the MIT License.

## 🆘 Support

For support and questions, please open an issue on GitHub or contact the development team.

---

*Built with ❤️ for refugees worldwide*
