

import React from 'react';

interface ProgressBarProps {
  value: number; // 0 to 100
  className?: string;
}

const ProgressBar: React.FC<ProgressBarProps> = ({ value, className = '' }) => {
  const cappedValue = Math.min(100, Math.max(0, value));

  return (
    <div className={`w-full bg-gray-200 rounded-full h-2.5 dark:bg-gray-700 ${className}`}>
      <div
        className="bg-primary-600 h-2.5 rounded-full transition-all duration-300 ease-in-out"
        style={{ width: `${cappedValue}%` }}
      ></div>
    </div>
  );
};

export default ProgressBar;