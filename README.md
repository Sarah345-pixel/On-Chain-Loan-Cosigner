# 🤝 On-Chain Loan Cosigner

A decentralized loan cosigning platform built on Stacks blockchain that enables shared responsibility lending with transparent risk management.

## 🚀 Features

- **Loan Creation** 📝 - Borrowers can create loan requests with custom terms
- **Cosigner Approval** ✅ - Secure cosigner request and approval system  
- **Automated Funding** 💰 - Smart contract handles loan disbursement
- **Payment Tracking** 📊 - Real-time payment history and status monitoring
- **Default Management** ⚠️ - Transparent default declaration and handling
- **User Statistics** 📈 - Track lending history and performance metrics

## 🛠️ Contract Functions

### For Borrowers

#### `create-loan`
```clarity
(create-loan amount interest-rate duration-blocks)
```
- **amount**: Loan amount in microSTX
- **interest-rate**: Annual interest rate (max 50%)
- **duration-blocks**: Loan duration in blocks (1008-52560)

#### `request-cosigner`
```clarity
(request-cosigner loan-id cosigner-principal)
```
Send a cosigner request for your pending loan.

#### `make-payment`
```clarity
(make-payment loan-id payment-amount)
```
Make payments towards your active loan.

### For Cosigners

#### `approve-cosigning`
```clarity
(approve-cosigning borrower-principal)
```
Approve a cosigner request from a borrower.

### For Lenders

#### `fund-loan`
```clarity
(fund-loan loan-id)
```
Fund an approved loan (requires cosigner approval).

### Read-Only Functions

#### `get-loan`
```clarity
(get-loan loan-id)
```
Get basic loan information.

#### `get-loan-details`
```clarity
(get-loan-details loan-id)
```
Get comprehensive loan details including payment info and status.

#### `get-user-stats`
```clarity
(get-user-stats user-principal)
```
Get user's lending statistics and history.

#### `is-loan-overdue`
```clarity
(is-loan-overdue loan-id)
```
Check if a loan payment is overdue.

## 📋 Loan Statuses

- **pending** 🕐 - Loan created, awaiting cosigner
- **approved** ✅ - Cosigner approved, ready for funding
- **active** 🔄 - Loan funded, payments in progress
- **completed** ✅ - Loan fully repaid
- **defaulted** ❌ - Loan in default

## 💡 Usage Example

1. **Create a Loan** 📝
   ```clarity
   (contract-call? .on-chain-loan create-loan u1000000 u15 u10080)
   ```
   Creates a 1 STX loan with 15% interest for ~10 weeks.

2. **Request Cosigner** 🤝
   ```clarity
   (contract-call? .on-chain-loan request-cosigner u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
   ```

3. **Approve Cosigning** ✅
   ```clarity
   (contract-call? .on-chain-loan approve-cosigning 'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
   ```

4. **Fund the Loan** 💰
   ```clarity
   (contract-call? .on-chain-loan fund-loan u1)
   ```

5. **Make Payments** 💸
   ```clarity
   (contract-call? .on-chain-loan make-payment u1 u100000)
   ```

## ⚡ Getting Started

1. Deploy the contract using Clarinet:
   ```bash
   clarinet deploy
   ```

2. Interact with the contract through Clarinet console:
   ```bash
   clarinet console
   ```

3. Test the contract:
   ```bash
   clarinet test
   ```

## 🔒 Security Features

- **Access Control** - Only authorized users can perform specific actions
- **Input Validation** - All inputs are validated for safety
- **Overflow Protection** - Safe arithmetic operations
- **Emergency Withdrawal** - Owner can withdraw funds in emergencies

## 📊 Risk Management

- **Shared Responsibility** - Both borrower and cosigner share default risk
- **Payment Tracking** - Automatic overdue detection
- **Credit History** - User statistics track lending performance
- **Transparent Terms** - All loan terms stored on-chain

## 🌟 Why Use On-Chain Loan Cosigner?

- **Trustless** 🔐 - No central authority required
- **Transparent** 👁️ - All transactions visible on blockchain  
- **Immutable** 🔒 - Contract terms cannot be changed
- **Global Access** 🌍 - Available to anyone with STX
- **Low Fees** 💰 - Minimal transaction costs

## 🤝 Contributing

Feel free to submit issues and pull requests to improve the contract functionality and security.

## ⚖️ License

MIT License - see LICENSE file for details.
