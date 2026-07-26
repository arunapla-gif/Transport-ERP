import React from 'react';

export function Input({ label, id, className = "", ...props }) {
  return (
    <div className={`flex flex-col group ${className}`}>
      {label && (
        <label htmlFor={id} className="text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-1 transition-colors group-focus-within:text-indigo-600">
          {label}
        </label>
      )}
      <input
        id={id}
        className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-800 font-medium placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500 focus:bg-white hover:border-slate-300 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] disabled:bg-slate-50 disabled:text-slate-400 disabled:opacity-75 disabled:hover:border-slate-200"
        {...props}
      />
    </div>
  );
}
