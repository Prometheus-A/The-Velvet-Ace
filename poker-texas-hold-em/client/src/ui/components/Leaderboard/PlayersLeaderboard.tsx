import type React from "react";

interface PlayersLeaderboardProps {
  players: {
    id: number;
    name: string;
    stakes: string;
  }[];
}

const PlayersLeaderboard: React.FC<PlayersLeaderboardProps> = ({ players }) => {
  return (
    <div className="bg-[#1B2446] rounded-2xl overflow-hidden border border-[#1e2b4a] flex-1">
      <div className="p-4 text-center">
        <h2 className="text-white text-xl tracking-wider">
          PLAYERS LEADERBOARD
        </h2>
      </div>
      <div className="grid grid-cols-2 text-[#D1DBFF] text-sm px-4 py-2 border-b border-[#7B8CC5]">
        <div>Player Name</div>
        <div className="text-right">Stakes</div>
      </div>
      <div className="divide-y divide-[#1e2b4a]">
        {players.map((player, index) => (
          <div
            key={player.id}
            className={`grid grid-cols-2 px-4 py-3 text-white ${
              index % 2 === 0 ? "bg-[#0A1128]" : " bg-[#1B2446]"
            }`}
          >
            <div>{player.name}</div>
            <div className="text-right">{player.stakes}</div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default PlayersLeaderboard;
