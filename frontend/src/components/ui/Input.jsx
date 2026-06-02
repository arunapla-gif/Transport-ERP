import React from 'react';

export function Input({ label, id, className = "", ...props }) {
  return (
    <div className={`flex flex-col gap-1.5 ${className}`}>
      {label && (
        <label htmlFor={id} className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">
          {label}
        </label>
      )}
      <input
        id={id}
        className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-800 font-medium placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 focus:bg-white transition-all disabled:bg-slate-50 disabled:text-slate-400"
        {...props}
      />
    </div>
  );
}
