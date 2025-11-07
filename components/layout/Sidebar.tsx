

import React from 'react';
import ChartBarIcon from '../icons/ChartBarIcon';
import UsersIcon from '../icons/UsersIcon';
import PaperAirplaneIcon from '../icons/PaperAirplaneIcon';
import { View } from '../../App';

interface SidebarProps {
  currentView: View;
  setView: (view: View) => void;
}

const Sidebar: React.FC<SidebarProps> = ({ currentView, setView }) => {
  const navItems = [
    { view: 'DASHBOARD' as View, label: 'Dashboard', icon: ChartBarIcon },
    { view: 'ULTRA_FAST_SEND' as View, label: 'Ultra-Fast Send', icon: PaperAirplaneIcon },
    { view: 'ACCOUNTS' as View, label: 'Accounts', icon: UsersIcon },
  ];

  const baseClasses = 'flex items-center px-4 py-3 rounded-lg text-gray-600 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors duration-200';
  const activeClasses = 'bg-primary-100 dark:bg-primary-900/50 text-primary-700 dark:text-primary-300 font-semibold';

  return (
    <aside className="w-64 bg-white dark:bg-gray-800 p-4 flex flex-col border-r border-gray-200 dark:border-gray-700">
      <nav className="flex-1 space-y-2">
        {navItems.map((item) => {
          const Icon = item.icon;
          return (
            <button
              key={item.view}
              onClick={() => setView(item.view)}
              className={`${baseClasses} ${currentView === item.view ? activeClasses : ''}`}
            >
              <Icon className="h-5 w-5 mr-3" />
              <span>{item.label}</span>
            </button>
          );
        })}
      </nav>
      <div className="mt-auto text-center text-xs text-gray-400">
        <p>Speed-Send MVP v1.0</p>
      </div>
    </aside>
  );
};

export default Sidebar;