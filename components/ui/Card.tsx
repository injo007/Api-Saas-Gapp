

import React from 'react';

interface CardProps {
  children: React.ReactNode;
  className?: string;
}

interface CardHeaderProps { // Modified: No longer extends CardProps directly to make children optional
  children?: React.ReactNode; // Made optional
  className?: string;
  title?: string;
}

const Card: React.FC<CardProps> = ({ children, className = '' }) => {
  return (
    <div className={`bg-white dark:bg-gray-800 shadow-sm rounded-lg border border-gray-200 dark:border-gray-700 overflow-hidden ${className}`}>
      {children}
    </div>
  );
};

export const CardHeader: React.FC<CardHeaderProps> = ({ children, className = '', title }) => (
    <div className={`p-4 border-b border-gray-200 dark:border-gray-700 ${className}`}>
      {title && <h2 className="text-lg font-semibold text-gray-800 dark:text-gray-100">{title}</h2>}
      {children}
    </div>
);

export const CardContent: React.FC<CardProps> = ({ children, className = '' }) => (
    <div className={`p-4 ${className}`}>{children}</div>
);

export const CardFooter: React.FC<CardProps> = ({ children, className = '' }) => (
    <div className={`p-4 bg-gray-50 dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700 ${className}`}>{children}</div>
);


export default Card;