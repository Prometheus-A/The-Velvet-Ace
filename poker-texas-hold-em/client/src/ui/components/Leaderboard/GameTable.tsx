import type React from "react";
import TableRow from "./TableRow";

interface GameTableProps {
  tables: {
    id: number;
    tableName: string;
    game: string;
    type: string;
    player: string;
    stakes: string;
    status: "view" | "watch";
  }[];
  isMobile: boolean;
}

const GameTable: React.FC<GameTableProps> = ({ tables, isMobile }) => {
  return (
    <div className=" overflow-hidden">
      {!isMobile ? (
        // Desktop view - table layout
        <div className="overflow-x-auto">
          <div className="w-full" style={{ minWidth: "850px" }}>
            <div className="grid grid-cols-6 text-gray-400 p-2.5 border-b text-xs font-normal border-[#7B8CC5]">
              <div className="">Table Name</div>
              <div className="">Game</div>
              <div className="">Type</div>
              <div className="">Player</div>
              <div className="">Stakes</div>
              <div className="">Action</div>
            </div>
            <div className="divide-y divide-[#1e2b4a]">
              {tables.map((table, index) => (
                <TableRow
                  key={table.id}
                  table={table}
                  index={index}
                  isMobile={false}
                />
              ))}
            </div>
          </div>
        </div>
      ) : (
        // Mobile view - card layout
        <div className="p-4 bg-[#121B3A] space-y-2">
          {tables.map((table, index) => (
            <TableRow
              key={table.id}
              table={table}
              index={index}
              isMobile={true}
            />
          ))}
        </div>
      )}

      <div className="flex justify-end items-center pt-6 pr-2 text-white text-sm">
        <div className="flex items-center text-sm font-normal">
          <span className="mr-2">Statistics:</span>
          <img src="/images/user.svg" className="w-4 h-4" />
          <span className="">256 Players</span>
        </div>
      </div>
    </div>
  );
};

export default GameTable;
