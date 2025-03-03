<!-- Logo -->
<p align="center">
  <img src="https://data.inpi.fr/image/marques/FR4873300" width="200">
</p>

<!-- Animated Header -->
<h1 align="center" style="background: linear-gradient(to right, #ff00cc, #3333ff); -webkit-background-clip: text; -webkit-text-fill-color: transparent;">
🎲 On-Chain Casino
</h1>

<!-- Casino GIF -->
<p align="center">
  <img src="https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExYW0zZ2JzZXN1emRrYXo1czRianlwdXRyMHJqd2tndmd6cXpsZWx0bCZlcD12MV9naWZzX3NlYXJjaCZjdD1n/3o6MbqNPaatT8nnEmk/giphy.gif" width="400">
</p>



<p align="center">
  <a href="https://your-build-link-here">
    <img src="https://img.shields.io/badge/build-passing-brightgreen?style=for-the-badge&flat" alt="Build Status">
  </a>
</p>

<p align="center">
  <a href="https://cairo-lang.org">
    <img src="https://img.shields.io/badge/-%F0%9F%90%AB%20%20Cairo-black?style=for-the-badge&flat&logo=Cairo" alt="Cairo">
  </a>
  <a href="https://reactjs.org">
    <img src="https://img.shields.io/badge/-React-black?style=for-the-badge&flat&logo=react" alt="React">
  </a>
</p>

<p align="center">
  <a href="https://t.me/+tqBpITsr5mllZDQ0">
    <img src="https://img.shields.io/badge/-Telegram-blue?style=for-the-badge&flat&logo=telegram" alt="Telegram">
  </a>
</p>

---
## 🔥 Have you ever played a game and wondered if the developers rigged it in their favor—or worse, for someone else? 🃏  

In traditional casinos, cheating comes in many forms, but **this is different**.  
Built entirely **on-chain** on **Starknet**, our casino ensures **fairness, transparency, and trustless gameplay**—no hidden tricks, no shady business.  
Just pure, provably fair gaming.  

---

## Features


- 🖥️ **Cairo Language**: Written in Cairo for Starknet deployment
- ⚛️ **React Frontend**: Modern React-based UI for playing the game
 - 🎮 **Onchain Gaming**: Fully onchain game logic 



---

## 👥 Contributors  

A huge shoutout to all the amazing contributors who made this project possible! 💖  

<a href="https://github.com/Prometheus-A/The-Velvet-Ace/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=Prometheus-A/The-Velvet-Ace" />
</a>

---

## 📖 Resources  

  ###  [Contributor's guide](https://github.com/Prometheus-A/The-Velvet-Ace/blob/main/poker-texas-hold-em/GameREADME.md) >
### [Setting up the Project](./CONTRIBUTING.md) >

---

## ❓ Need Help?  

Join our **Telegram group** for discussions and updates.  
📩 For any questions, drop a message in the group or reach out to   <a href="https://t.me/lemonade46" style="display: inline-flex; align-items: center; text-decoration: none; font-weight: bold; font-size: 18px; color: #0088cc; margin-left: 20px;">
  @lemonade
</a>





 

---

<!-- Scrolling Marquee Text -->
<marquee behavior="alternate" direction="left" style="font-size: 20px; color: #f39c12;">
🚀 The future of online gaming is here. Play fair, play on-chain! 
</marquee>

<!-- Play Now Button -->
<p align="center">
  <a href="#" style="
    background-color: #ff00ff;
    color: white;
    padding: 10px 20px;
    border-radius: 5px;
    text-decoration: none;
    font-weight: bold;
    font-size: 46px;
    text-decoration: none;
    width: 100px;
    height: 100px;
  ">🎮 </a>
</p>

---

## Part 2: Installing Dojo and Its Tools

This section covers the installation and setup of the Dojo Engine and its tools, assuming `asdf` is already installed (see Part 1).

### Prerequisites
- Git and Curl installed.
- Rust (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`).
- A cloned repo: `git clone https://github.com/krishnabandewar/ODBuild.git && cd ODBuild`.

### Installation Steps
1. **Install Dojo with `dojoup`**:
   ```bash
   curl -L https://install.dojoengine.org | bash
   source ~/.bashrc  # Reload shell
   dojoup --version  # Verify
Installs sozo, katana, and torii.
Build the Project:

sozo build
Run Locally with Katana:

katana --chain-id TEST
Deploy to Katana: In a new terminal:

sozo migrate
Query with Torii (optional):

torii --world <WORLD_ADDRESS>
Access at http://localhost:8080/graphql.
Troubleshooting
No Scarb.toml? Run sozo init and add dojo = "0.6.0" to Scarb.toml.
Windows? Use WSL2.
Questions? Ping @lemonade46 on Telegram.

## Part 2: Installing Dojo and Its Tools

This section provides a detailed guide to installing and setting up the Dojo Engine and its associated tools (`sozo`, `katana`, and `torii`). It assumes you’ve already installed `asdf` as described in Part 1 of this README. These steps are based on the official Dojo Engine documentation ([dojoengine.org/getting-started](https://www.dojoengine.org/getting-started)).

### Prerequisites

Before starting, ensure the following are set up on your system:
- **Git**: For cloning the repository. Install with:
  - Ubuntu: `sudo apt install git`
  - macOS: `brew install git`
  - Verify: `git --version` (e.g., "git version 2.34.1")
- **Curl**: For downloading the installer. Install with:
  - Ubuntu: `sudo apt install curl`
  - macOS: `brew install curl`
  - Verify: `curl --version` (e.g., "curl 7.81.0")
- **Rust**: Required for compiling Dojo components. Install with:
  ```bash
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  source $HOME/.cargo/env
  rustc --version  # Should return something like "rustc 1.75.0"
  ```
- **Cloned Repository**: Clone your fork of the project:
  ```bash
  git clone https://github.com/krishnabandewar/ODBuild.git
  cd ODBuild
  ```
  - Replace `ODBuild` with the actual repository name if different. Confirm it worked by running `ls` (or `dir` on WSL) to see the project files.

**Note**: These steps assume a Unix-based system (Linux/macOS). For Windows, install WSL2 (Windows Subsystem for Linux) with `wsl --install` in PowerShell and use a WSL terminal.

### Installation Steps

#### 1. Install Dojo with `dojoup`

The easiest way to install Dojo and its tools is via `dojoup`, a single-command installer.
- Run:
  ```bash
  curl -L https://install.dojoengine.org | bash
  ```
  - This command fetches and executes a script from the Dojo Engine site to install the Dojo binaries in your home directory (e.g., `~/.dojo/bin`).
- Reload your shell to update the PATH:
  ```bash
  source ~/.bashrc  # Use ~/.zshrc if you’re on Zsh
  ```
  - This ensures your terminal recognizes the newly installed commands.
- Verify installation:
  ```bash
  dojoup --version  # Example output: "dojoup 0.6.0"
  ```
  - **What this does**: Installs `sozo` (project manager), `katana` (local blockchain), and `torii` (indexer). You can confirm these are installed by running `sozo --version`, `katana --version`, and `torii --version`.

#### 2. Build the Project

Compile the Dojo project in your repository:
- Run:
  ```bash
  sozo build
  ```
  - **What this does**: Uses `sozo` to compile any Cairo code in the project (e.g., in `src/` directory) into executable artifacts stored in the `target/` directory.
  - **Expected Output**: A success message like "Successfully built project." If there’s no Cairo code yet, you might see an error—see Troubleshooting below.

#### 3. Run Locally with Katana

Test your project on a local blockchain using `katana`:
- Run:
  ```bash
  katana --chain-id TEST
  ```
  - **What this does**: Starts a local Dojo blockchain node for development. Keep this terminal running; you’ll see logs indicating the node is active (e.g., "Listening on 0.0.0.0:5050").

#### 4. Deploy to Katana

Deploy your project to the local blockchain:
- In a new terminal (from the repo directory):
  ```bash
  sozo migrate
  ```
  - **What this does**: Deploys the compiled artifacts to the running Katana node.
  - **Expected Output**: Includes a "World address" (e.g., `0x1234...`). Save this address for the next step.

#### 5. Query with Torii (Optional)

Index and query your deployed project with `torii`:
- Run:
  ```bash
  torii --world <WORLD_ADDRESS>
  ```
  - Replace `<WORLD_ADDRESS>` with the address from `sozo migrate`.
  - **What this does**: Starts an indexer to track on-chain data and provides a GraphQL API.
  - Access the GraphQL interface at: `http://localhost:8080/graphql`. Test it by opening the URL in a browser or using a GraphQL client (e.g., Postman).

### Troubleshooting

- **Missing `Scarb.toml`?**
  - If your repo lacks a `Scarb.toml` file, initialize a Dojo project:
    ```bash
    sozo init
    ```
  - Edit `Scarb.toml` to include:
    ```toml
    [dependencies]
    dojo = "0.6.0"
    ```
- **Command Not Found?**
  - Ensure your PATH is updated: `export PATH="$HOME/.dojo/bin:$PATH"`.
  - Reload your shell (`source ~/.bashrc`) or restart your terminal.
- **Windows Users**: Use WSL2 (install via `wsl --install` in PowerShell).
- **Still Stuck?** Contact `@lemonade46` on Telegram or join the TVA group.

