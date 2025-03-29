  // Mock data for the game tables with explicit type for status
  export const gameTables: {
    id: number;
    tableName: string;
    game: string;
    type: string;
    player: string;
    stakes: string;
    status: "view" | "watch";
  }[] = [
    {
      id: 1,
      tableName: "Mithini #30",
      game: "Hold'em",
      type: "No limit",
      player: "5/6",
      stakes: "$0.05/$0.1",
      status: "view",
    },
    {
      id: 2,
      tableName: "Mithini #30",
      game: "Hold'em",
      type: "No limit",
      player: "6/6",
      stakes: "$0.05/$0.1",
      status: "watch",
    },
    {
      id: 3,
      tableName: "Mithini #30",
      game: "Hold'em",
      type: "No limit",
      player: "5/6",
      stakes: "$0.05/$0.1",
      status: "view",
    },
    {
      id: 4,
      tableName: "Mithini #30",
      game: "Hold'em",
      type: "No limit",
      player: "5/6",
      stakes: "$0.05/$0.1",
      status: "view",
    },
    {
      id: 5,
      tableName: "Mithini #30",
      game: "Hold'em",
      type: "No limit",
      player: "5/6",
      stakes: "$0.05/$0.1",
      status: "view",
    },
    {
      id: 6,
      tableName: "Mithini #30",
      game: "Hold'em",
      type: "No limit",
      player: "6/6",
      stakes: "$0.05/$0.1",
      status: "watch",
    },
    {
      id: 7,
      tableName: "Mithini #30",
      game: "Hold'em",
      type: "No limit",
      player: "5/6",
      stakes: "$0.05/$0.1",
      status: "view",
    },
    {
      id: 8,
      tableName: "Mithini #30",
      game: "Hold'em",
      type: "No limit",
      player: "5/6",
      stakes: "$0.05/$0.1",
      status: "view",
    },
    {
      id: 9,
      tableName: "Mithini #30",
      game: "Hold'em",
      type: "No limit",
      player: "5/6",
      stakes: "$0.05/$0.1",
      status: "view",
    },
  ];

  // Mock data for players leaderboard
  export const players = [
    { id: 1, name: "ALVAROJORG", stakes: "$1500" },
    { id: 2, name: "ALVAROJORG", stakes: "$1500" },
    { id: 3, name: "ALVAROJORG", stakes: "$1500" },
    { id: 4, name: "ALVAROJORG", stakes: "$1500" },
    { id: 5, name: "ALVAROJORG", stakes: "$1500" },
    { id: 6, name: "ALVAROJORG", stakes: "$1500" },
    { id: 7, name: "ALVAROJORG", stakes: "$1500" },
    { id: 8, name: "ALVAROJORG", stakes: "$1500" },
  ];