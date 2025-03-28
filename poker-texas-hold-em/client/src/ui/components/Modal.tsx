import { ReactNode, useEffect } from 'react';
import { createPortal } from 'react-dom';

type ModalProps = {
  isOpen: boolean;
  onClose: () => void;
  children: ReactNode;
  closeOnOverlayClick?: boolean;
  className?: string;
  width?: string; 
};

const Modal = ({
  isOpen,
  onClose,
  children,
  closeOnOverlayClick = true,
  className = '',
  width = 'max-w-md',
}: ModalProps) => {
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = 'auto';
    }

    return () => {
      document.body.style.overflow = 'auto';
    };
  }, [isOpen]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };

    if (isOpen) {
      window.addEventListener('keydown', handleKeyDown);
    }

    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return createPortal(
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div
        className="fixed inset-0 bg-[#121c3e]/70 backdrop-blur-sm transition-opacity"
        aria-hidden="true"
        onClick={closeOnOverlayClick ? onClose : undefined}
      />

      {/* Modal container with gradient border */}
      <div 
        className={`relative w-full rounded-2xl bg-[#010925] p-[1px] ${width} ${className}`}
        style={{
          background: 'linear-gradient(156.46deg, #FFD700 15.68%, #B7860F 84.83%)'
        }}
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-headline"
      >
        {/* Inner content */}
        <div className="w-full h-full rounded-2xl bg-[#010925] overflow-hidden">
          <div className="p-6">
            {children}
          </div>
        </div>
      </div>
    </div>,
    document.body
  );
};


export default Modal;