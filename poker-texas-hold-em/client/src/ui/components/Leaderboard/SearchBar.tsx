"use client";
import type React from "react";

interface SearchBarProps {
  value: string;
  onChange: (value: string) => void;
}

const SearchBar: React.FC<SearchBarProps> = ({ value, onChange }) => {
  return (
    <div className="relative w-full max-w-md">
      <input
        type="text"
        placeholder="Search"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full bg-[#0A1128] text-white rounded-lg py-2.5 px-4 pl-10 focus:outline-none focus:ring-1 focus:ring-[#182a60]"
      />
    </div>
  );
};

export default SearchBar;
