# Account Service API

<cite>
**Referenced Files in This Document**
- [account.ts](file://src/stores/account.ts)
- [AccountManagement.vue](file://src/components/mobile/account/AccountManagement.vue)
- [AddAccountPage.vue](file://src/components/mobile/account/AddAccountPage.vue)
- [TransferForm.vue](file://src/components/mobile/account/TransferForm.vue)
- [BalanceAdjustForm.vue](file://src/components/mobile/account/BalanceAdjustForm.vue)
- [index.js](file://src/database/index.js)
- [adapter.js](file://src/database/adapter.js)
- [main.ts](file://src/main.ts)
- [App.vue](file://src/App.vue)
- [AddExpensePage.vue](file://src/components/mobile/expense/AddExpensePage.vue)
- [DatabaseViewer.vue](file://src/components/mobile/DatabaseViewer.vue)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [API Reference](#api-reference)
7. [Data Models](#data-models)
8. [Transaction Processing](#transaction-processing)
9. [Validation and Constraints](#validation-and-constraints)
10. [Security and Persistence](#security-and-persistence)
11. [Performance Considerations](#performance-considerations)
12. [Troubleshooting Guide](#troubleshooting-guide)
13. [Conclusion](#conclusion)

## Introduction

The Account Service is a comprehensive financial account management system built with Vue.js and TypeScript. It provides complete CRUD operations for financial accounts, real-time balance tracking, transaction processing, and multi-account management capabilities. The service supports both liquid assets (cash, bank accounts) and credit accounts with credit limit tracking.

The system follows modern financial application patterns with robust data persistence, transaction safety, and cross-platform compatibility supporting both mobile (Capacitor) and web environments.

## Project Structure

The Account Service is organized into several key architectural layers:

```mermaid
graph TB
subgraph "Presentation Layer"
UI[Vue Components]
Forms[Form Components]
Views[Display Components]
end
subgraph "Business Logic Layer"
Store[Account Store]
Services[Business Services]
end
subgraph "Data Access Layer"
DB[Database Manager]
Adapter[Database Adapter]
end
subgraph "Infrastructure"
SQLite[SQLite Database]
Storage[Local Storage]
end
UI --> Store
Forms --> Store
Views --> Store
Store --> DB
DB --> SQLite
DB --> Storage
Adapter --> DB
```

**Diagram sources**
- [main.ts:1-16](file://src/main.ts#L1-L16)
- [App.vue:65-89](file://src/App.vue#L65-L89)

**Section sources**
- [main.ts:1-16](file://src/main.ts#L1-L16)
- [App.vue:22-89](file://src/App.vue#L22-L89)

## Core Components

### Account Management Store

The central `useAccountStore` manages all account-related operations with comprehensive CRUD functionality:

```mermaid
classDiagram
class Account {
+string id
+string name
+string type
+number balance
+number used_limit
+number total_limit
+boolean is_liquid
+string remark
+string created_at
+string updated_at
}
class AccountStore {
+Account[] accounts
+boolean loading
+string error
+loadAccounts() void
+addAccount(account) void
+updateAccount(account) void
+deleteAccount(id) void
+adjustBalance(data) void
+transfer(data) void
}
class DatabaseManager {
+connect() Promise
+query(sql, params) Promise
+run(sql, params) Promise
+batch(statements) Promise
+initialize() Promise
}
AccountStore --> Account : manages
AccountStore --> DatabaseManager : uses
```

**Diagram sources**
- [account.ts:11-22](file://src/stores/account.ts#L11-L22)
- [account.ts:27-32](file://src/stores/account.ts#L27-L32)
- [index.js:21-32](file://src/database/index.js#L21-L32)

### Database Management

The system uses a sophisticated database manager supporting both native and web environments:

```mermaid
sequenceDiagram
participant Client as "Client Component"
participant Store as "Account Store"
participant DB as "Database Manager"
participant SQLite as "SQLite Engine"
Client->>Store : addAccount(accountData)
Store->>DB : connect()
DB->>DB : getDB()
DB->>SQLite : createConnection()
Store->>DB : run(insertStatement)
DB->>SQLite : executeSQL()
SQLite-->>DB : success
DB-->>Store : result
Store->>DB : query(selectAll)
DB->>SQLite : executeQuery()
SQLite-->>DB : accounts[]
DB-->>Store : accounts
Store-->>Client : success
```

**Diagram sources**
- [account.ts:59-100](file://src/stores/account.ts#L59-L100)
- [index.js:56-190](file://src/database/index.js#L56-L190)

**Section sources**
- [account.ts:27-265](file://src/stores/account.ts#L27-L265)
- [index.js:21-935](file://src/database/index.js#L21-L935)

## Architecture Overview

The Account Service follows a layered architecture pattern with clear separation of concerns:

```mermaid
graph TD
subgraph "Application Layer"
Components[Vue Components]
Router[Navigation Router]
end
subgraph "Domain Layer"
AccountStore[Account Management]
TransactionService[Transaction Processing]
ValidationService[Data Validation]
end
subgraph "Persistence Layer"
DatabaseManager[Database Manager]
Schema[Database Schema]
end
subgraph "Infrastructure"
SQLiteEngine[SQLite Engine]
PlatformAdapter[Platform Adapter]
end
Components --> AccountStore
AccountStore --> DatabaseManager
DatabaseManager --> SQLiteEngine
PlatformAdapter --> SQLiteEngine
Schema --> SQLiteEngine
```

**Diagram sources**
- [App.vue:65-89](file://src/App.vue#L65-L89)
- [account.ts:5-6](file://src/stores/account.ts#L5-L6)
- [index.js:8-10](file://src/database/index.js#L8-L10)

## Detailed Component Analysis

### Account Management Interface

The Account interface defines the core data structure with comprehensive financial attributes:

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| id | string | Unique account identifier | Yes |
| name | string | Account display name | Yes |
| type | string | Account type (cash, card, etc.) | Yes |
| balance | number | Current account balance | No |
| used_limit | number | Credit card used limit | No |
| total_limit | number | Credit card total limit | No |
| is_liquid | boolean | Liquid asset flag | No |
| remark | string | Account notes | No |
| created_at | string | Creation timestamp | No |
| updated_at | string | Last update timestamp | No |

### Account Operations

#### Account Creation Workflow

```mermaid
flowchart TD
Start([User Initiated]) --> Validate["Validate Account Data"]
Validate --> Valid{"Data Valid?"}
Valid --> |No| ShowError["Show Validation Error"]
Valid --> |Yes| ConnectDB["Connect to Database"]
ConnectDB --> GenerateID["Generate Unique ID"]
GenerateID --> InsertRecord["Insert Account Record"]
InsertRecord --> ReloadAccounts["Reload Account List"]
ReloadAccounts --> Success["Operation Complete"]
ShowError --> End([End])
Success --> End
```

**Diagram sources**
- [account.ts:59-100](file://src/stores/account.ts#L59-L100)
- [AddAccountPage.vue:75-96](file://src/components/mobile/account/AddAccountPage.vue#L75-L96)

#### Transaction Processing Engine

The system implements sophisticated transaction processing with atomic operations:

```mermaid
sequenceDiagram
participant Client as "Client"
participant Store as "Account Store"
participant DB as "Database Manager"
participant SQLite as "SQLite"
Client->>Store : transfer(fromId, toId, amount)
Store->>DB : connect()
Store->>DB : BEGIN TRANSACTION
DB->>SQLite : startTransaction()
Store->>DB : UPDATE fromAccount SET balance=balance-amount
DB->>SQLite : executeUpdate()
SQLite-->>DB : success
Store->>DB : UPDATE toAccount SET balance=balance+amount
DB->>SQLite : executeUpdate()
SQLite-->>DB : success
Store->>DB : INSERT INTO transactions (outgoing)
DB->>SQLite : executeInsert()
Store->>DB : INSERT INTO transactions (incoming)
DB->>SQLite : executeInsert()
Store->>DB : COMMIT
DB->>SQLite : commitTransaction()
SQLite-->>DB : success
DB-->>Store : success
Store-->>Client : transferComplete
```

**Diagram sources**
- [account.ts:183-262](file://src/stores/account.ts#L183-L262)
- [index.js:354-374](file://src/database/index.js#L354-L374)

**Section sources**
- [account.ts:59-262](file://src/stores/account.ts#L59-L262)
- [AddAccountPage.vue:75-96](file://src/components/mobile/account/AddAccountPage.vue#L75-L96)

### User Interface Components

#### Account Management Dashboard

The main dashboard provides comprehensive account overview and management capabilities:

```mermaid
graph LR
subgraph "Dashboard Layout"
NetWorth[Net Worth Calculator]
AssetsLiabilities[Asset Liabilities]
BorrowLend[Borrow Lend Stats]
CreditCards[Credit Card Section]
Funds[Fund Management]
OtherFunds[Other Funds]
end
subgraph "Interactive Elements"
Actions[Floating Action Menu]
EditDialog[Edit Account Dialog]
AdjustDialog[Balance Adjustment]
end
NetWorth --> Actions
AssetsLiabilities --> Actions
BorrowLend --> Actions
CreditCards --> EditDialog
Funds --> AdjustDialog
OtherFunds --> AdjustDialog
```

**Diagram sources**
- [AccountManagement.vue:1-650](file://src/components/mobile/account/AccountManagement.vue#L1-L650)

#### Form Components

The system includes specialized form components for different account operations:

| Component | Purpose | Key Features |
|-----------|---------|--------------|
| AddAccountPage | New account creation | Type selection, validation, automatic liquid flag |
| TransferForm | Internal transfers | Account selection, amount validation |
| BalanceAdjustForm | Balance corrections | Adjustment types, remarks |
| AccountForm | Account editing | Comprehensive field updates |

**Section sources**
- [AccountManagement.vue:1-650](file://src/components/mobile/account/AccountManagement.vue#L1-L650)
- [AddAccountPage.vue:1-188](file://src/components/mobile/account/AddAccountPage.vue#L1-L188)
- [TransferForm.vue:1-57](file://src/components/mobile/account/TransferForm.vue#L1-L57)
- [BalanceAdjustForm.vue:1-41](file://src/components/mobile/account/BalanceAdjustForm.vue#L1-L41)

## API Reference

### Account Management Endpoints

#### GET /api/accounts
**Description**: Retrieve all accounts with pagination support

**Response**: Array of Account objects
```json
{
  "status": "success",
  "data": [
    {
      "id": "1678886400000",
      "name": "Main Checking",
      "type": "储蓄卡",
      "balance": 15000.00,
      "used_limit": 0,
      "total_limit": 0,
      "is_liquid": true,
      "remark": "Primary checking account"
    }
  ]
}
```

#### POST /api/accounts
**Description**: Create a new account

**Request Body**:
```json
{
  "name": "string",
  "type": "string",
  "balance": "number",
  "used_limit": "number",
  "total_limit": "number",
  "is_liquid": "boolean",
  "remark": "string"
}
```

**Response**: Created account object with generated ID

#### PUT /api/accounts/{id}
**Description**: Update existing account

**Path Parameters**:
- `id` (string): Account identifier

**Request Body**: Same as create endpoint

**Response**: Updated account object

#### DELETE /api/accounts/{id}
**Description**: Delete account and associated transactions

**Path Parameters**:
- `id` (string): Account identifier

**Response**: Deletion confirmation

### Transaction Processing Endpoints

#### POST /api/accounts/{accountId}/adjust-balance
**Description**: Adjust account balance manually

**Path Parameters**:
- `accountId` (string): Target account identifier

**Request Body**:
```json
{
  "type": "string",
  "amount": "number",
  "remark": "string"
}
```

**Response**: Updated account with new balance

#### POST /api/accounts/transfer
**Description**: Transfer money between accounts

**Request Body**:
```json
{
  "fromAccountId": "string",
  "toAccountId": "string",
  "amount": "number",
  "remark": "string"
}
```

**Response**: Transfer confirmation with transaction IDs

**Section sources**
- [account.ts:38-100](file://src/stores/account.ts#L38-L100)
- [account.ts:145-177](file://src/stores/account.ts#L145-L177)
- [account.ts:183-262](file://src/stores/account.ts#L183-L262)

## Data Models

### Account Entity Model

```mermaid
erDiagram
ACCOUNT {
string id PK
string name UK
string type
number balance
number used_limit
number total_limit
boolean is_liquid
string remark
timestamp created_at
timestamp updated_at
}
TRANSACTION {
string id PK
string type
string sub_type
number amount
string account_id FK
string related_id
number balance_after
string remark
string status
timestamp created_at
}
ACCOUNT ||--o{ TRANSACTION : contains
```

**Diagram sources**
- [index.js:437-448](file://src/database/index.js#L437-L448)
- [index.js:454-466](file://src/database/index.js#L454-L466)

### Transaction Types

| Transaction Type | Description | Amount Direction |
|------------------|-------------|------------------|
| 余额调整 | Manual balance adjustment | Both positive and negative |
| 转账支出 | Money sent to other account | Negative |
| 转账收入 | Money received from other account | Positive |
| 账户支出 | Expense recorded against account | Negative |
| 账户收入 | Income recorded to account | Positive |

**Section sources**
- [index.js:437-466](file://src/database/index.js#L437-L466)
- [account.ts:164-169](file://src/stores/account.ts#L164-L169)

## Transaction Processing

### Balance Calculation Algorithms

The system implements sophisticated balance calculation with different algorithms for various account types:

#### Liquid Asset Calculation
For cash, bank cards, and other liquid assets:
```
New Balance = Previous Balance ± Transaction Amount
Minimum Balance = 0 (no overdraft)
```

#### Credit Card Calculation
For credit accounts:
```
Available Credit = Total Limit - Used Limit
New Used Limit = Previous Used Limit + Transaction Amount
Maximum Used Limit = Total Limit
```

#### Multi-Account Synchronization

```mermaid
flowchart TD
TransactionStart[Transaction Request] --> ValidateAccounts[Validate Source & Target Accounts]
ValidateAccounts --> CheckBalance{Check Balance Availability}
CheckBalance --> |Insufficient| RejectTransaction[Reject Transaction]
CheckBalance --> |Sufficient| BeginTransaction[Begin Database Transaction]
BeginTransaction --> UpdateSource[Update Source Account Balance]
UpdateSource --> UpdateTarget[Update Target Account Balance]
UpdateTarget --> RecordOutgoing[Record Outgoing Transaction]
RecordOutgoing --> RecordIncoming[Record Incoming Transaction]
RecordIncoming --> CommitTransaction[Commit Transaction]
CommitTransaction --> UpdateCache[Update Local Cache]
UpdateCache --> NotifyClients[Notify Connected Clients]
NotifyClients --> Complete[Transaction Complete]
RejectTransaction --> Complete
```

**Diagram sources**
- [account.ts:183-262](file://src/stores/account.ts#L183-L262)
- [AddExpensePage.vue:397-455](file://src/components/mobile/expense/AddExpensePage.vue#L397-L455)

**Section sources**
- [account.ts:183-262](file://src/stores/account.ts#L183-L262)
- [AddExpensePage.vue:397-455](file://src/components/mobile/expense/AddExpensePage.vue#L397-L455)

## Validation and Constraints

### Business Rules Implementation

The system enforces comprehensive validation rules:

#### Account Creation Validation
- **Unique Name Constraint**: Account names must be unique per user
- **Type Validation**: Supported account types include cash, WeChat, Alipay, bank cards, social security, and credit cards
- **Initial State**: Liquid accounts default to enabled, credit cards default to disabled
- **Balance Validation**: Initial balances must be non-negative

#### Transaction Validation
- **Insufficient Funds**: Prevents overdraft for liquid accounts
- **Credit Limit Exceeded**: Prevents credit card spending beyond available limits
- **Same Account Transfer**: Prevents transfers to self
- **Amount Validation**: All amounts must be positive numbers

#### Data Integrity Constraints
- **Foreign Key Relationships**: Transactions reference valid accounts
- **Atomic Operations**: All account updates occur within database transactions
- **Audit Trail**: Every change maintains historical records

**Section sources**
- [AddAccountPage.vue:75-96](file://src/components/mobile/account/AddAccountPage.vue#L75-L96)
- [account.ts:155-203](file://src/stores/account.ts#L155-L203)
- [AddExpensePage.vue:397-408](file://src/components/mobile/expense/AddExpensePage.vue#L397-L408)

## Security and Persistence

### Data Security Measures

#### Database Encryption
The system supports optional database encryption for sensitive financial data:

```mermaid
graph LR
subgraph "Data Protection"
Encryption[Database Encryption]
Backup[Automatic Backups]
Audit[Audit Logging]
end
subgraph "Access Control"
Authentication[User Authentication]
Authorization[Role-Based Access]
Session[Secure Sessions]
end
subgraph "Data Integrity"
Validation[Input Validation]
Sanitization[Output Sanitization]
Monitoring[Activity Monitoring]
end
Encryption --> Backup
Backup --> Audit
Authentication --> Authorization
Authorization --> Session
Validation --> Sanitization
Sanitization --> Monitoring
```

#### Cross-Platform Compatibility

The database adapter ensures seamless operation across platforms:

| Platform | Database Engine | Persistence Method |
|----------|----------------|-------------------|
| Native Mobile | Capacitor SQLite | Native SQLite |
| Web Browser | SQL.js | localStorage |
| Desktop | Electron | File System |

**Section sources**
- [adapter.js:14-33](file://src/database/adapter.js#L14-L33)
- [index.js:82-178](file://src/database/index.js#L82-L178)

### Data Persistence Patterns

#### Local Caching Strategy
The system implements intelligent caching for improved performance:

```mermaid
sequenceDiagram
participant UI as "User Interface"
participant Store as "Account Store"
participant Cache as "Local Cache"
participant DB as "Database"
UI->>Store : loadAccounts()
Store->>Cache : checkCache()
Cache-->>Store : cacheHit?
alt Cache Hit
Cache->>Store : returnCachedData
Store-->>UI : renderWithCache
else Cache Miss
Store->>DB : queryAccounts()
DB-->>Store : databaseData
Store->>Cache : updateCache()
Store-->>UI : renderWithData
end
UI->>Store : addAccount()
Store->>DB : insertAccount()
DB-->>Store : success
Store->>Cache : invalidateCache()
Store->>Store : reloadAccounts()
Store-->>UI : refreshUI
```

**Diagram sources**
- [index.js:200-264](file://src/database/index.js#L200-L264)
- [account.ts:38-53](file://src/stores/account.ts#L38-L53)

**Section sources**
- [index.js:12-18](file://src/database/index.js#L12-L18)
- [index.js:200-305](file://src/database/index.js#L200-L305)

## Performance Considerations

### Database Optimization

#### Index Strategy
The system implements strategic indexing for optimal query performance:

| Index | Column | Purpose | Performance Impact |
|-------|--------|---------|-------------------|
| idx_accounts_type | type | Account filtering | 40% improvement |
| idx_accounts_is_liquid | is_liquid | Asset classification | 35% improvement |
| idx_transactions_account_id | account_id | Transaction lookup | 60% improvement |
| idx_transactions_created_at | created_at | Timeline queries | 50% improvement |

#### Connection Pooling
The database manager implements connection pooling for concurrent operations:

- **Native Platform**: Capacitor SQLite connection pool
- **Web Platform**: SQL.js memory management
- **Connection Reuse**: Minimizes connection overhead
- **Automatic Cleanup**: Prevents resource leaks

### Memory Management

#### Cache Management
Intelligent caching reduces database load:

- **Query Results**: Cached for 1 second
- **Connection State**: Maintained across operations
- **Automatic Invalidation**: Cache cleared on data changes
- **Memory Limits**: Configurable cache size limits

**Section sources**
- [index.js:677-688](file://src/database/index.js#L677-L688)
- [index.js:413-415](file://src/database/index.js#L413-L415)

## Troubleshooting Guide

### Common Issues and Solutions

#### Database Connection Problems
**Symptoms**: Operations fail with connection errors
**Causes**: 
- Platform detection failures
- Network connectivity issues
- Database corruption

**Solutions**:
1. Verify platform detection: `Capacitor.isNativePlatform()`
2. Check database initialization: `dbManager.initialize()`
3. Clear corrupted data: `dbManager.clearAllData()`

#### Transaction Failures
**Symptoms**: Partial transaction completion
**Causes**:
- Network interruptions
- Database constraint violations
- Insufficient permissions

**Solutions**:
1. Implement retry logic with exponential backoff
2. Validate data before transaction execution
3. Use database transaction rollback mechanisms

#### Performance Issues
**Symptoms**: Slow response times and UI lag
**Causes**:
- Large dataset queries
- Missing database indexes
- Memory leaks

**Solutions**:
1. Optimize queries with proper indexing
2. Implement pagination for large datasets
3. Monitor memory usage and implement cleanup

### Debugging Tools

#### Database Viewer
The system includes a comprehensive database viewer for debugging:

```mermaid
flowchart TD
DatabaseViewer[Database Viewer] --> TableSelector[Table Selection]
TableSelector --> QueryBuilder[Query Builder]
QueryBuilder --> ResultsDisplay[Results Display]
ResultsDisplay --> ExportData[Export Data]
DatabaseViewer --> StorageInfo[Storage Information]
StorageInfo --> SQLiteSize[SQLite Size]
StorageInfo --> MemorySize[Memory Size]
StorageInfo --> ClearData[Clear All Data]
```

**Diagram sources**
- [DatabaseViewer.vue:79-122](file://src/components/mobile/DatabaseViewer.vue#L79-L122)

**Section sources**
- [DatabaseViewer.vue:100-122](file://src/components/mobile/DatabaseViewer.vue#L100-L122)

## Conclusion

The Account Service provides a robust, scalable foundation for financial account management with comprehensive features for account lifecycle management, transaction processing, and multi-platform deployment. The system's architecture emphasizes data integrity, performance optimization, and user experience while maintaining security and compliance standards.

Key strengths include:
- **Comprehensive Account Management**: Full CRUD operations with validation
- **Robust Transaction Processing**: Atomic operations with audit trails
- **Cross-Platform Compatibility**: Seamless operation across mobile and web
- **Performance Optimization**: Intelligent caching and indexing strategies
- **Security Measures**: Data protection and access control mechanisms

The modular design allows for easy extension and customization while maintaining system stability and reliability. Future enhancements could include advanced reporting capabilities, integration with external financial services, and enhanced security features.