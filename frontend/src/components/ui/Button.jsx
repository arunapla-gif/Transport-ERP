import React from 'react';

export function Button({ variant = 'primary', className = "", children, ...props }) {
  const baseStyle = "inline-flex items-center justify-center font-semibold rounded-xl transition-all duration-200 active:scale-95 text-sm disabled:opacity-50 disabled:pointer-events-none disabled:active:scale-100";
  
  const variants = {
    primary: "bg-indigo-600 text-white hover:bg-indigo-700 shadow-md shadow-indigo-500/20 px-5 py-2.5",
    secondary: "bg-slate-100 text-slate-800 border border-slate-200 hover:bg-slate-200 px-5 py-2.5",
    success: "bg-emerald-600 text-white hover:bg-emerald-500 shadow-md shadow-emerald-500/20 px-5 py-2.5",
    danger: "bg-rose-600 text-white hover:bg-rose-700 shadow-md shadow-rose-500/20 px-5 py-2.5",
    icon: "p-2 rounded-lg bg-slate-100 text-slate-600 hover:bg-slate-200",
    iconDanger: "p-2 rounded-lg bg-red-50 text-red-600 hover:bg-red-100",
  };

  return (
    <button className={`${baseStyle} ${variants[variant]} ${className}`} {...props}>
      {children}
    </button>
  );
}
