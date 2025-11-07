

import React from 'react';
import PaperAirplaneIcon from '../icons/PaperAirplaneIcon';

const Header: React.FC = () => {
  return (
    <header className="bg-white dark:bg-gray-800 shadow-md">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center">
            <PaperAirplaneIcon className="h-8 w-8 text-primary-600 transform -rotate-45" />
            <h1 className="ml-3 text-2xl font-bold text-gray-900 dark:text-white">Speed-Send</h1>
          </div>
          {/* Placeholder for user menu or other actions */}
          <div className="flex items-center">
             <div className="w-8 h-8 bg-gray-300 rounded-full dark:bg-gray-600"></div>
          </div>
        </div>
      </div>
    </header>
  );
};

export default Header;