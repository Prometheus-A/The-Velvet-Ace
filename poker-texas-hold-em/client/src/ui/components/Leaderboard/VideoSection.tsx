import type React from "react"

const VideoSection: React.FC = () => {
  return (
    <div className="w-full aspect-square bg-[#1B2446] border border-[#FFD700] max-h-[240px] rounded-2xl overflow-hidden">
      {/* This would typically contain a video player or animated content */}
      {/* For now, we'll use a placeholder that matches the design */}
      <div className="w-full h-full flex items-center justify-center">
        {/* You can replace this with actual video content */}
        <div className="text-gray-600 text-sm">Casino Video/Animation</div>
      </div>
    </div>
  )
}

export default VideoSection

