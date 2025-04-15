# Getting Started with Dojo: Installation & Setup Guide
This guide provides step-by-step instructions to install and set up Dojo along with its essential **tools**. Follow the steps below to get started quickly.

## Prerequisites
1. Operating System:
* Linux/macOS (Recommended)
* Windows (Requires a Linux environment such as WSL, GitHub Codespaces, or a cloud-based Linux VM, as Dojo does not natively support Windows)

2. Rust (programming language)
3. Scarb (package manager)
4. Git (for version control)


## Installation
Dojo runs on Rust, making it the **standard** choice for installation. This guide covers setup on **Linux/macOS**, the recommended environment.

### Step 1 - Install Rust
This command downloads a script that installs rustup, which then installs the latest stable version of Rust.
```sh 
$ curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf |
```

For more details, refer to the [official Rust installation guide](https://doc.rust-lang.org/book/ch01-01-installation.html).

### Step 2 - Install Scarb 

#### **Option 1: Install Scarb via Script (Recommended)** 
The easiest way to install Scarb is through the official installation of script. 

* Run the following in your terminal, then follow the onscreen instructions. This will install the latest stable release.

```sh
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
```

* When setting up Dojo, the required Scarb version depends on the Dojo version needed for the project. E.g if your project needs **Dojo 1.1.0**, install **Scarb 2.9.2** to ensure compatibility. 
Run: 

```sh
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh -s -- -v 2.9.2
```


#### **Option 2: Install Scarb via asdf (Version Management Recommended)**  
Using asdf allows easy version switching for different projects.
First install asdf by following the [official installation guide.](https://asdf-vm.com/guide/getting-started.html) Then run the following command to add the scarb plugin:

```sh
asdf plugin add scarb
```
Show all installable versions:

```sh
asdf list all scarb
```
Install latest version:

```sh
asdf install scarb latest
```
Install specific version:

```sh
asdf install scarb 2.9.2
```
Set a version globally (in your ``~/.tool-versions file``):

```sh
asdf set -u scarb latest
```

To verify installation 
   ```sh
   scarb --version
   ```  
   If the output shows version no. e.g `2.9.2`, the installation was successful. 

###  Step 3 - Install Dojoup
Dojo is built around a set of development tools - Katana, Torii and Sozo, which are all installed with dojoup.
```sh
curl -L https://install.dojoengine.org | bash
```
* To install the latest dojo release
```sh 
dojoup
```
## Install Dojo Using `asdf` 
#### Step 1 - Add the asdf-dojo plugin
This plugin allows `asdf` to manage Dojo versions.

```sh
asdf plugin add dojo https://github.com/dojoengine/asdf-dojo
```

#### Step 2 - Install the latest or a specific version

```sh 
asdf install dojo latest      # For the latest version
asdf install dojo 1.0.0       # For a specific version
``` 
#### Step 3 - Set the global or local version
After installation, you need to tell `asdf` which version of Dojo to use. There are two ways to do this:

```sh 
asdf global dojo latest       # Set globally
asdf local dojo 1.0.0        # Set locally in your project directory
```
  The global version makes the latest Dojo version the default across your system.
  The local version makes **version 1.0.0** active only within the directory where you run the command. This is useful when different projects require different Dojo versions.

## How to Setup & Run a Dojo Project 

* ### **Check for Installed Dojo Tools** 
To set up your project, ensure that the necessary Dojo tools are installed by running `dojoup`.
To verify that **Sozo** is installed (which also ensures all tools including Katana and Torii are available), run: 

```sh
sozo --version
```

* ### **Navigate to Your Project Directory** 
Move into your project's directory—the location where your **Scarb.toml** file is present. 

For example, if your project is **Velvet Ace**, and its directory is inside `The-Velvet-Ace/poker-texas-hold-em/contracts/`, run: 

```sh
cd The-Velvet-Ace/poker-texas-hold-em/contracts/
```

To confirm you are in the correct directory, list all files: 

```sh
ls -al
```
If **Scarb.toml** is present, you are in the right place to set up your project.

---


### **Step 1: Build the Project** 

Run: 
```sh
sozo build
```
If the project has no errors, it will build successfully.

---

### **Step 2: Run Katana (Local Blockchain)** 
Open a **new terminal** and navigate to the same project directory (**where `Scarb.toml` is located**). 
Then, run: 

```sh
katana --dev --dev.no-fee
```

---

### **Step 3: Migrate (Deploy) the Contract to Katana** 
Return to the terminal where you built the project using **Sozo**, then run: 

```sh
sozo migrate
```
Once migration is successful, note your **world address** from the output.

---

### **Step 4: Start Torii Server with World Address** 


Copy your **world address** from the `sozo migrate` output, then open a **new terminal** or use terminal where sozo was built and run: 

```sh
torii --world <your-world-address> --http.cors_origins "*"
```
Replace `<your-world-address>` with the actual world address from `sozo migrate`.

---

**Your project is now deployed to Katana, and Torii is indexing the data!**

