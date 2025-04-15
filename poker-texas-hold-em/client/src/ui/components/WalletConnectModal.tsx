import { useState } from "react";
import Modal from "./Modal";
import Button from "./LandingPage/Button";

const wallets = [
  { name: "Argent", icon: "/wallets/argent.svg" },
  { name: "Braavos", icon: "/wallets/braavos.svg" }
];

type Props = {
  isOpen: boolean;
  onClose: () => void; 
  connect: (x: boolean) => void; // simulate connect wallet
}

type Wallet = {
  name: string;
  icon: string;
}

const WalletConnectModal = ({ isOpen, onClose, connect }: Props) => {
  const [searchTerm, setSearchTerm] = useState<string>("");
  const [isWalletLoading, setIsWalletLoading] = useState(false);
  const [selectedWallet, setSelectedWallet] = useState<Wallet | null>(null);

  const filteredWallets = wallets.filter(wallet =>
    wallet.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleWalletConnect = (wallet: Wallet) => {
    setSelectedWallet(wallet);
    setIsWalletLoading(true);
    
    // Simulate async connection
    setTimeout(() => {
      setIsWalletLoading(false);
      onClose();
      connect(true);
    }, 2000);

  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} width="max-w-lg">
      <div className="grid gap-y-6 py-4">
        <h3 className="font-orbitron text-xl text-center font-semibold text-white">
          Connect Wallet
        </h3>
        
        {isWalletLoading ? (
          <div className="text-center text-white grid gap-y-4 py-4">
            <div className="flex items-center justify-between mb-4 bg-[#0A1128] rounded-full py-[17px] px-[20px]">
                <span className="font-bold text-[#9DA0A9]">{selectedWallet?.name}</span> 
                <span className="animate-pulse">...</span> 
            </div>
            <div className="flex flex-col items-center justify-center gap-y-6">
                {selectedWallet?.icon && (
                  <img 
                    src={selectedWallet.icon} 
                    className="rounded-full h-[74px] w-[74px]" 
                    alt={`${selectedWallet.name} icon`} 
                  />
                )}
                <span className="animate-pulse">Connecting...</span>
            </div>
          </div>
        ) : (
          <>
            <div className="relative">
              <input
                type="search"
                placeholder="Search "
                className="w-full rounded-2xl bg-[#0A1128] p-3 pl-10 text-white placeholder-[#9DA0A9]"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>

            <div className="grid gap-y-2">
              {filteredWallets.map((wallet) => (
                <button
                  key={wallet.name}
                  className="flex w-full cursor-pointer items-center justify-between rounded-lg bg-[hsla(227,44%,19%,0.8)] py-2 px-3 transition-all duration-200 hover:bg-[hsla(227,44%,25%,0.9)] border border-[hsla(227,44%,25%,0.3)] hover:border-[hsla(227,44%,35%,0.5)]"
                  onClick={() => handleWalletConnect(wallet)}
                >
                  <div className="flex items-center gap-x-3">
                    {wallet.icon && (
                      <img 
                        src={wallet.icon} 
                        alt={wallet.name} 
                        className="h-8 w-8"
                      />
                    )}
                    <span className="font-medium text-white">{wallet.name}</span>
                  </div>
                  <div className="w-[7px] h-[7px] rounded-full bg-[#B7860F]"></div>
                </button>
              ))}
            </div>
          </>
        )}

        <Button 
          variant="gradient" 
          fullWidth 
          radius="full"
          onClick={onClose}
        >
          Cancel
        </Button>
      </div>
    </Modal>
  );
};

export default WalletConnectModal;