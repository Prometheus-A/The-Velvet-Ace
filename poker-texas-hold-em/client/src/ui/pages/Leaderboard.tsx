"use client";
import type React from "react";
import { useState } from "react";
import { useMediaQuery } from "../hooks/use-media-query";
import Switch from "../components/Leaderboard/Switch";
import SearchBar from "../components/Leaderboard/SearchBar";
import PlayersLeaderboard from "../components/Leaderboard/PlayersLeaderboard";
import VideoSection from "../components/Leaderboard/VideoSection";
import GameTable from "../components/Leaderboard/GameTable";
import { gameTables, players } from "../data/leaderboard-mock";
const Leaderboard: React.FC = () => {
  const [showFull, setShowFull] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");


  const isMobile = useMediaQuery("(max-width: 768px)");
  return (
    <div className="flex flex-col bg-[#0A1128] min-h-screen">
      <div className="flex flex-col md:flex-row gap-6 p-4 xl:p-6 2xl:container 2xl:mx-auto">
        <div className="flex-1 rounded-2xl bg-[#1B2446] p-4 md:p-6 md:w-[75%] h-auto">
          {!isMobile && (
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between mb-6 gap-4">
              <div className="flex items-center space-x-4">
                <Switch
                  id="show-full"
                  checked={showFull}
                  onCheckedChange={setShowFull}
                  label="Full"
                  labelClassName="text-white"
                />
                <Switch
                  id="show-empty"
                  checked={!showFull}
                  onCheckedChange={(checked) => setShowFull(!checked)}
                  label="Empty"
                  labelClassName="text-white"
                />
              </div>
              <SearchBar value={searchQuery} onChange={setSearchQuery} />
            </div>
          )}
          {isMobile && (
            <div className="flex flex-col w-full gap-y-5">
              <div className="grid grid-cols-2 w-full justify-between items-center">
                <h1 className="font-semibold text-2xl text-white">Lobby </h1>
                <SearchBar value={searchQuery} onChange={setSearchQuery} />
              </div>
              <p className="font-normal text-sm text-[#7B8CC5]">
                List of available Table
              </p>
            </div>
          )}
          <GameTable tables={gameTables} isMobile={isMobile} />
        </div>
        <div className="w-full md:w-[25%] flex flex-col gap-y-4">
          <VideoSection />
          <PlayersLeaderboard players={players} />
        </div>
      </div>
    </div>
  );
};

export default Leaderboard;
