"use client"

import type React from "react"

interface SwitchProps {
  id?: string
  checked: boolean
  onCheckedChange: (checked: boolean) => void
  className?: string
  label?: string
  labelClassName?: string
}

const Switch: React.FC<SwitchProps> = ({
  id,
  checked,
  onCheckedChange,
  className = "",
  label,
  labelClassName = "",
}) => {
  return (
    <div className="flex items-center space-x-2">
      {label && (
        <label htmlFor={id} className={`text-sm font-medium ${labelClassName}`}>
          {label}
        </label>
      )}
      <div
        className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${checked ? "bg-yellow-400" : "bg-gray-600"} ${className}`}
        onClick={() => onCheckedChange(!checked)}
        data-state={checked ? "checked" : "unchecked"}
      >
        <span
          className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${checked ? "translate-x-6" : "translate-x-1"}`}
        />
        {id && <input type="checkbox" id={id} className="sr-only" checked={checked} readOnly />}
      </div>
    </div>
  )
}

export default Switch

