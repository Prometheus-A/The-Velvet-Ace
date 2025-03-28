import { ReactNode } from 'react';

type ButtonVariant = 
  | 'gradient' 
  | 'transparent'
  | 'solid-red'
  | 'solid-yellow'
  | 'outline-green'
  | 'outline-yellow';

type ButtonSize = 'sm' | 'md' | 'lg';
type ButtonRadius = 'none' | 'sm' | 'md' | 'lg' | 'full';

interface ButtonProps {
  children: ReactNode;
  variant?: ButtonVariant;
  size?: ButtonSize;
  radius?: ButtonRadius;
  fullWidth?: boolean;
  className?: string;
  onClick?: () => void;
  disabled?: boolean;
}

const Button = ({
  children,
  variant = 'solid-red',
  size = 'lg',
  radius = 'lg',
  fullWidth = false,
  className = '',
  onClick,
  disabled = false,
}: ButtonProps) => {
  // Base classes
  const baseClasses = 'font-medium cursor-pointer transition-all font-inter duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed';

  // Variant classes
  const variantClasses = {
    'gradient': 'bg-gradient-to-r from-[#B31926] to-[#4D0B10] text-white',
    'transparent': 'bg-transparent text-gray-800 hover:bg-gray-100 focus:ring-gray-300 dark:text-white dark:hover:bg-gray-800',
    'solid-red': 'bg-[#B31926] text-white hover:bg-[#8A0F1A] border-3 border-[#FFD700]',
    'solid-yellow': 'bg-[#FFD700] text-black hover:bg-[#E5C100] border-3 border-[#B31926]',
    'outline-green': 'bg-[#19172E] text-white ',
    'outline-yellow': 'bg-[#19172E] text-[#FFD700] hover:bg-yellow-50'
  };

  // Size classes
  const sizeClasses = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-base',
    lg: 'px-6 py-3 text-lg',
  };

  // Radius classes
  const radiusClasses = {
    none: 'rounded-none',
    sm: 'rounded-sm',
    md: 'rounded-md',
    lg: 'rounded-[12px]',
    full: 'rounded-full',
  };

  // Width class
  const widthClass = fullWidth ? 'w-full' : 'w-fit';

  // Gradient border variants
  const getWrapperGradient = () => {
    switch(variant) {
      case 'gradient':
        return 'bg-gradient-to-r from-[#FFD700] to-[#B7860F]';
      case 'outline-green':
        return 'bg-gradient-to-b from-[#00CF00] to-[#006900]';
      case 'outline-yellow':
        return 'bg-gradient-to-b from-[#FFD700] to-[#B7860F]';
      default:
        return '';
    }
  };

  const wrapperGradient = getWrapperGradient();
  const requiresWrapper = wrapperGradient !== '';

  if (requiresWrapper) {
    return (
      <div
        className={`
          p-[1px]
          ${radiusClasses[radius]}
          ${widthClass}
          ${wrapperGradient}
        `}
      >
        <button
          className={`
            ${baseClasses}
            ${variantClasses[variant]}
            ${sizeClasses[size]}
            ${radiusClasses[radius]}
            w-full
            h-full
            ${className}
          `}
          onClick={onClick}
          disabled={disabled}
        >
          {children}
        </button>
      </div>
    );
  }

  return (
    <button
      className={`
        ${baseClasses}
        ${variantClasses[variant]}
        ${sizeClasses[size]}
        ${radiusClasses[radius]}
        ${widthClass}
        ${className}
      `}
      onClick={onClick}
      disabled={disabled}
    >
      {children}
    </button>
  );
};

export default Button;