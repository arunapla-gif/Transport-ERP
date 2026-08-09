import React, { useRef, useState, useEffect } from 'react';
import { ChevronDown } from 'lucide-react';

export default function Accordion({ 
  title, 
  icon: Icon, 
  children, 
  isOpen, 
  onToggle,
  defaultOpen = false,
  badge = null,
  summary = null
}) {
  // If controlled by parent, use isOpen, else manage internal state
  const [internalOpen, setInternalOpen] = useState(defaultOpen);
  const isCurrentlyOpen = isOpen !== undefined ? isOpen : internalOpen;
  
  const contentRef = useRef(null);

  const handleToggle = () => {
    if (onToggle) {
      onToggle();
    } else {
      setInternalOpen(!internalOpen);
    }
  };

  return (
    <div className={`border rounded-xl mb-3 transition-all duration-300 ${isCurrentlyOpen ? 'border-indigo-200 bg-white shadow-sm shadow-indigo-900/5' : 'border-slate-200 bg-[#F8F6F0]/50 hover:bg-white hover:border-slate-300'}`}>
      
      {/* Accordion Header */}
      <button 
        type="button"
        onClick={handleToggle}
        className="w-full flex items-center justify-between p-4 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-1 rounded-xl text-left"
      >
        <div className="flex items-start gap-3">
          {Icon && (
            <div className={`p-1.5 rounded-md transition-colors mt-0.5 ${isCurrentlyOpen ? 'bg-indigo-100 text-indigo-600' : 'bg-slate-100 text-slate-500'}`}>
              <Icon size={18} />
            </div>
          )}
          <div className="flex flex-col">
            <div className="flex items-center">
              <h3 className={`font-bold transition-colors ${isCurrentlyOpen ? 'text-indigo-900' : 'text-slate-700'}`}>
                {title}
              </h3>
              {badge && isCurrentlyOpen && (
                <span className="px-2 py-0.5 text-[10px] font-black uppercase tracking-wider bg-emerald-100 text-emerald-700 rounded-full ml-2">
                  {badge}
                </span>
              )}
            </div>
            {/* The Summary Preview (Only visible when closed) */}
            {!isCurrentlyOpen && summary && (
              <p className="text-xs text-slate-500 font-medium mt-1 pr-4 animate-in fade-in duration-300">
                <span className="text-indigo-400 mr-1.5">↳</span>
                {summary}
              </p>
            )}
          </div>
        </div>
        
        <div className={`p-1 rounded-full transition-all duration-300 ${isCurrentlyOpen ? 'bg-indigo-50 text-indigo-500 transform rotate-180' : 'text-slate-400 hover:bg-slate-100'}`}>
          <ChevronDown size={18} />
        </div>
      </button>

      {/* Accordion Content (Smooth height transition) */}
      <div 
        ref={contentRef}
        className="overflow-hidden transition-all duration-300 ease-in-out"
        style={{ 
          maxHeight: isCurrentlyOpen ? (contentRef.current?.scrollHeight || 2000) + 'px' : '0px',
          opacity: isCurrentlyOpen ? 1 : 0
        }}
      >
        <div className="p-4 pt-0 border-t border-indigo-50/50">
          {children}
        </div>
      </div>
      
    </div>
  );
}
