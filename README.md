# SC Node
The SC Node (Sovereign Circle Node) is a low-cost, self-hosted mini-PC setup designed to run basic banking infrastructure (nodes, pools, exchanges, etc.) for its owner and members. Its successful operation depends on a constant connection with a bigger, more complete, node (i.e. “SC Cluster” Node) with technical support readily available. The SC Node only requires a wired ethernet internet connection and nothing more to just work. This repository contains all the resources to program and configure a new SC Node for future Sovereign Circle owners.

## Objectives and Key Functions
* Run a full AZCoin node to contribute to the broader AZCoin blockchain's decentralization with the ability to sweep AZCoin private keys.
* Integrate Bitcoin, AZCoin, and microcurrencies wallets that allow real-time visibility into incoming member deposits. Operate a Lightning Node with a channel to its “SC Cluster” Node.
* This Lightning node provides Lightning as a Service (LaaS) to the members of its Sovereign Circle via the Satoshiware mobile wallet app.
* The SC Node includes Stratum v1.0 mining servers for both Bitcoin and AZCoin (connected via Stratum v2.0 on the backend). This allows Sovereign Circle members to connect their miners to efficiently pool hashrate and earn AZCoin and Bitcoin mining rewards. Proceeds are deposited directly into their SC Node exchange accounts.
* Lightweight, self-hosted exchange service to enable seamless swapping between AZCoin (or the local microcurrency) and SATS.
* Owner Dashboard: A secure web interface enabling node owners to perform essential management tasks, including member administration, moving deposits and funds, and oversight of the SC Node's core components.
* Member Dashboard: A secure, user-friendly web interface enabling community members to interact with the SC Node's exchange, perform deposits and withdrawals, mining configuration, and manage basic account functions such as viewing transaction history, balances, and open orders.

## Hardware Specifications
* RAM: 32 GB
* SSD: 2 TB
* CPU: 4 Cores (Must Support Virtualization, i.e., Hyper-V Capable)
* Networking: Gigabit Ethernet
* Power: Low-Power Consumption (<50W)

## Proxmox VE
Proxmox VE serves as the foundational hypervisor for the SC Node, providing robust virtualization capabilities for running all associated software components efficiently on a single hardware platform. To ensure secure and simplified network exposure, the SC Node is configured with NAT addressing, presenting only a single external IP address to the broader network while handling internal traffic for VMs and containers. By default, the device name is set to "SC Node", but can be easily configured in the SC Node install script.

## Current Software Implementation (Jan 8th 2026)
### AZCoin Full Node w/ Basic Configuration
* ZeroMQ (ZMQ) Enabled for Push-Based Notifications
* API: Python w/ FastAPI (RESTful & WebSockets)
  * Single main wallet with accounting/labels — generate unique addresses per user, and track balances externally in the exchange database.
  * Static API Keys for Basic Internal Authorization (Rotate keys periodically for best security)
  * The ability to sweep private keys
* Backup/Restore: wallet.dat files
* Use the Assume Valid feature to speed up Initial Blockchain Download (IBD)

### Bitcoin Pruned Node w/ Basic Configuration
* ZeroMQ (ZMQ) Enabled for Push-Based Notifications
* API: Python w/ FastAPI (RESTful & WebSockets)
  * Main wallet with accounting/labels — generate unique addresses per user, and track balances externally in your database.
  * Static API Keys for Basic Internal Authorization (Rotate keys periodically for best security)
* Backup/Restore: wallet.dat file
* Prune=25000 (~25-100 GB); 6 months worth of Bitcoin Blockchain data to help keep Core Lightning in sync.
* Use the Assume Valid feature to speed up Initial Blockchain Download (IBD)

### Core Lightning Node
* Single large channel w/ the SC Cluster Node
* Auto balancing programmed with the trusted SC Cluster Node
* API: Python w/ FastAPI (RESTful & WebSockets)
  * Install reckless:cl-zmq plugin for local push notifications
  * Static API Keys for Basic Internal Authorization (Rotate keys periodically for best security)
* Backup/Restore: hsm_secret, lightningd.sqlite3, and emergency.recover files

### Stratum V2 Translation Proxy (SRI) (Bitcoin)
* Configure w/ High Verbosity (RUST_LOG=info or debug)
* API: Python w/ FastAPI (RESTful & WebSockets)
  * Use Python's asyncio to tail the log file (or pipe stdout) in real time.
  * Process data as desired and store rolling windows to a lightweight DB (SQLite).
  * Static API Keys for Basic Internal Authorization (Rotate keys periodically for best security)
* Backup: None

### Stratum V2 Translation Proxy (SRI) (AZCoin)
* Configure w/ High Verbosity (RUST_LOG=info or debug)
* API: Python w/ FastAPI (RESTful & WebSockets)
  * Use Python's asyncio to tail the log file (or pipe stdout) in real time.
  * Process data as desired and store rolling windows to a lightweight DB (SQLite).
  * Static API Keys for Basic Internal Authorization (Rotate keys periodically for best security)
* Backup: None

### Exchange: AZCoin (or the local microcurrency) w/ SATS
* Contains all member accounting (including deposit addresses)
* Connects w/ Bitcoin Core, AZCoin, and Core Lightning nodes to acquire and monitor deposit addresses
* Connects with Stratum Servers and updates accounts with mining payouts
* API: Python w/ FastAPI (RESTful & WebSockets)
  * Provide Lightning as a Service (LaaS)
  * Generate deposit addresses (or lightning invoices)
  * Has the ability to withdraw (send)

### Member Dashboard
* Shared login with BTCofAZ w/ 2FA<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
* Mining Info: Stats, Histogram, and Payouts
* Wallet: See Totals, Make Deposits & Withdrawals, and Inspect History (w/ Addresses)
* Exchange: Limit Orders, Personal & Global History, Trading Interface, Charts, etc.

