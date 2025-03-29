import type React from "react";

interface TableRowProps {
  table: {
    id: number;
    tableName: string;
    game: string;
    type: string;
    player: string;
    stakes: string;
    status: "view" | "watch";
  };
  index: number;
  isMobile: boolean;
}

const TableRow: React.FC<TableRowProps> = ({ table, index, isMobile }) => {
  if (isMobile) {
    // Mobile card view
    return (
      <div
        className={`py-2.5 px-4 text-white rounded-lg ${
          index % 2 === 0
            ? "bg-[#0A1128]"
            : "bg-[#1B2446] border-[0.5px] border-white"
        } border border-[#1e2b4a]`}
      >
        <div className="flex items-center ">
          <div className="  mr-2">
            <img src="/images/leaderboard-logo.svg" alt="logo" className="w-10 h-10" />
          </div>
          <div>
            {" "}
            <div className="text-lg font-medium">{table.tableName}</div>
            <div className="text-sm text-gray-400">
              {table.game} {table.type}
            </div>
          </div>
        </div>

        <div className="flex flex-col justify-between items-center mt-3 max-w-56 gap-y-1">
          <div className="flex w-full justify-between">
            <div className="text-xs text-gray-400">Number of people:</div>
            <div>{table.player}</div>
          </div>
          <div className="flex w-full justify-between">
            <div className="text-xs text-gray-400">Stakes</div>
            <div>{table.stakes}</div>
          </div>
        </div>
      </div>
    );
  }

  // Desktop table view
  return (
    <div
      className={`grid grid-cols-6 items-center p-2.5 text-white text-base font-normal rounded-lg ${
        index % 2 === 0 ? "bg-[#0A1128]" : " bg-[#1B2446]"
      }`}
    >
      <div className="">{table.tableName}</div>
      <div className="">{table.game}</div>
      <div className="">{table.type}</div>
      <div className="">{table.player}</div>
      <div className="">{table.stakes}</div>
      <div className="w-full ">
        {table.status === "view" ? (
          <button className="bg-gradient-to-r from-[#0AEF0A] to-[#068906] hover:bg-green-600 border border-[#FFD700] text-white py-1.5 rounded-2xl w-full text-center">
            View
          </button>
        ) : (
          <button className="bg-[#4A4E6999] hover:bg-[#393d5299] text-white py-1.5 rounded-2xl w-full text-center border border-[#FFD700]">
            Watch
          </button>
        )}
      </div>
    </div>
  );
};

export default TableRow;
