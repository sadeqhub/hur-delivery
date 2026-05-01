import { useState, useEffect } from 'react';

interface HeaderProps {
  onMobileMenuClick: () => void;
}

export default function Header({ onMobileMenuClick }: HeaderProps) {
  const [currentTime, setCurrentTime] = useState(new Date());

  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  return (
    <header className="bg-white border-b border-gray-200 px-3 sm:px-4 lg:px-6 py-3 lg:py-4 sticky top-0 z-20">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-3 flex-1 min-w-0">
          {/* Mobile menu button */}
          <button
            onClick={onMobileMenuClick}
            className="lg:hidden p-2 text-gray-600 hover:text-primary-600 hover:bg-gray-50 rounded-lg transition-colors"
            aria-label="Toggle menu"
          >
            <i className="fas fa-bars text-xl"></i>
          </button>
          
          <div className="min-w-0 flex-1">
            <h1 className="text-lg sm:text-xl lg:text-2xl font-bold text-gray-900 truncate">
              لوحة التحكم الإدارية
            </h1>
            <p className="text-xs sm:text-sm text-gray-500 hidden sm:block">
              Hur Delivery Admin Panel
            </p>
          </div>
        </div>
        
        <div className="flex items-center gap-2 sm:gap-4 flex-shrink-0">
          {/* Date/Time - hide on very small screens */}
          <div className="text-right hidden sm:block">
            <div className="text-xs sm:text-sm font-medium text-gray-900">
              {currentTime.toLocaleDateString('ar-IQ', { 
                weekday: 'long', 
                year: 'numeric', 
                month: 'long', 
                day: 'numeric' 
              })}
            </div>
            <div className="text-xs text-gray-500">
              {currentTime.toLocaleTimeString('ar-IQ')}
            </div>
          </div>
          
          {/* Show only time on small screens */}
          <div className="text-right sm:hidden">
            <div className="text-xs font-medium text-gray-900">
              {currentTime.toLocaleTimeString('ar-IQ', { 
                hour: '2-digit', 
                minute: '2-digit' 
              })}
            </div>
          </div>
          
          <div className="w-px h-8 sm:h-10 bg-gray-200"></div>
          
          <button className="relative p-2 text-gray-600 hover:text-primary-600 hover:bg-gray-50 rounded-lg transition-colors">
            <i className="fas fa-bell text-lg sm:text-xl"></i>
            <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full"></span>
          </button>
        </div>
      </div>
    </header>
  );
}

