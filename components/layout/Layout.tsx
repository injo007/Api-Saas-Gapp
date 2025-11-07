
import React from 'react';
import Header from './Header';
import Sidebar from './Sidebar';
import { View } from '../../App';
import { ToastContainer } from '../ui/Toast';
import Dialog from '../ui/Dialog';

interface LayoutProps {
  children: React.ReactNode;
  currentView: View;
  setView: (view: View) => void;
}

const Layout: React.FC<LayoutProps> = ({ children, currentView, setView }) => {
  return (
    <div className="flex h-screen bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-100">
      <Sidebar currentView={currentView} setView={setView} />
      <div className="flex-1 flex flex-col overflow-hidden">
        <Header />
        <main className="flex-1 overflow-x-hidden overflow-y-auto">
          {children}
        </main>
      </div>
      <ToastContainer />
      <Dialog />
    </div>
  );
};

export default Layout;