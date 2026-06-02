import React from 'react';

export function Card({ title, icon, children, className = "" }) {
  return (
    <div className={`bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden mb-6 ${className}`}>
      {title && (
        <div className="px-6 py-5 border-b border-slate-100 flex justify-between items-center bg-slate-50/50">
          <h2 className="text-base font-bold text-slate-800 flex items-center gap-2">
            {icon && <span className="text-slate-400">{icon}</span>}
            {title}
          </h2>
        </div>
      )}
      <div className="p-6">
        {children}
      </div>
    </div>
  );
}
