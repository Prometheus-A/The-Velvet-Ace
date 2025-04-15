import { Link } from 'react-router-dom';
import Button from '../components/LandingPage/Button';
import { useEffect, useState } from 'react';
import WalletConnectModal from '../components/WalletConnectModal';
import ArrowDown from '../../assets/icons/ArrowDown';

const LandingPage = () => {
  const [isMobile, setIsMobile] = useState<boolean>(false);
  const [isWalletModalOpen, setIsWalletModalOpen] = useState<boolean>(false);
  const [isConnected, setIsConnected] = useState<boolean>(false);

  useEffect(() => {
    const handleResize = () => {
      setIsMobile(window.innerWidth < 560);
    };
    handleResize(); 
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  return (
    <section className="relative w-full h-screen max-h-screen overflow-hidden">
      {/* Nav */}
      {isConnected && <nav className='hidden lg:block fixed min-w-full' style={{ background: 'linear-gradient(180deg, #171E3A 47.51%, #3F53A0 360.64%)' }}>
        <div className='max-w-screen-2xl flex justify-between items-center mx-auto px-8 xl:px-10 py-3'>
          <div className='flex items-center gap-x-2'>
            <img src="/images/logo.svg" className='w-[80px] h-auto' alt="Velvet Ace Logo" />
            <p className='font-orbitron text-white font-semibold lg:text-[20px]'>Velvet Ace</p>
          </div>
          <div className='flex items-center cursor-pointer gap-x-1'>
            <div className='bg-yellow-300 w-[35px] h-[35px] rounded-[9px]'></div>
            <div className='mr-1'>
              <p className='text-xs text-white font-light'>0x12a...b34c</p>
              <p className='text-white font-bold'>$4000</p>
            </div>
            <ArrowDown />
          </div>
        </div>
      </nav>}

      {/* Background Image Container */}
      <div className="absolute inset-0 z-[-5]">
        <img 
          src={isMobile ? "/images/mobile-homebg.svg" : "/images/desktop-homebg.svg"}
          alt="Background"
          className="w-full h-full object-cover object-bottom"
        />
      </div>
      
      {/* Coin Images */}
      <div>
        <img
          src="/images/coin1.svg"
          alt="Coin"
          className="hidden lg:block w-[190px] h-auto absolute z-[2] left-[5%] top-[10%] opacity-60  2xl:scale-125"
        />
        <img
          src="/images/coin2.svg"
          alt="Coin"
          className="w-[108px] lg:w-[190px] h-auto absolute z-[2] left-[4%] top-[3%] lg:left-[23%] lg:top-[16%]  xl:scale-125 opacity-60"
        />
        <img
          src="/images/coin3.svg"
          alt="Coin"
          className="w-[187px] lg:w-[220px] h-auto absolute z-[2] right-[-20%] top-[17%] lg:right-[5%] lg:top-[30%] xl:scale-125 opacity-60"
        />
        <div className="sm:hidden z-0 h-auto absolute bottom-[-10%] right-[2%] w-full ">
          <img
            src="/images/coins-mobile.svg"
            alt=""
            className="object-cover h-[200px] object-right"
          />
        </div>
      </div>

      {/* Main Content */}
      <div className='relative z-10 w-full h-full flex flex-col items-center justify-center gap-y-4 lg:gap-8'>
        <img src="/images/logo.svg" className='w-[180px] md:w-[320px] h-auto' alt="Velvet Ace Logo" />
        <div className="absolute sm:hidden z-[-2] bottom-[-80%] max-w-[600px] mx-auto inset-0">
          <img 
            src="/images/board-mobile.svg"
            alt="Background"
            className="w-full h-full opacity-60 object-fill object-bottom"
          />
        </div>
        
        <h1 className="font-orbitron text-[37px] lg:text-8xl font-semibold animate-glow">
          <span className="
            text-[#E1E1E1]
            bg-clip-text
            tracking-tight
            drop-shadow-[0_0_6px_rgba(255,215,0,0.8)]
          ">
            Velvet Ace
          </span>
        </h1>

        {/* Buttons Container */}
        <div className='flex flex-col items-center md:flex-row gap-y-6 md:gap-4 mt-8'>
          <Button 
            variant='gradient' 
            radius='lg'
            onClick={() => setIsWalletModalOpen(true)}
            >
              {isConnected? "ENTER LOBBY" :"Connect Wallet to Play"}
          </Button>
          <Button variant='outline-green' radius='lg'>How to Play</Button>
        </div>

              
        {/* Terms Links */}
        <div className={`absolute bottom-10 font-orbitron text-xs lg:text-base ${isConnected ? 'lg:bottom-10 lg:right-10' : 'lg:top-5 lg:right-15'} flex gap-x-4 lg:gap-x-8 z-12 font-semibold text-white`}>
          <Link to=""><span className='cursor-pointer hover:text-yellow-300 transition-colors'>[ Terms and Conditions ]</span></Link>
          <Link to=""><span className='cursor-pointer hover:text-yellow-300 transition-colors'>[ Privacy Policy ]</span></Link>
        </div>
      </div>

       {/* Wallet Connect Modal */}
       <WalletConnectModal 
        isOpen={isWalletModalOpen} 
        onClose={() => setIsWalletModalOpen(false)} 
        connect={() => setIsConnected(true)}
      />
    </section>
  )
}

export default LandingPage;