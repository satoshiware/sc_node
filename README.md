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

## Softare
AZCoin Full Node w/ Basic Configuration
* ZeroMQ (ZMQ) Enabled for Push-Based Notifications
* API: Python w/ FastAPI (RESTful & WebSockets)
  * Wallet Needs, Need to create a unique wallet for each member with the ability to destroy wallets ensuring all funds are transferred to the master wallet

    Master w
    The ability to 
