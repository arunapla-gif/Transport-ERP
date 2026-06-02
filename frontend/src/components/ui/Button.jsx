import React from 'react';

export function Button({ variant = 'primary', className = "", children, ...props }) {
  const baseStyle = "inline-flex items-center justify-center font-semibold rounded-xl transition-all duration-200 active:scale-95 text-sm";
  
  const variants = {
    primary: "bg-gradient-to-br from-blue-600 to-indigo-700 text-white hover:from-blue-700 hover:to-indigo-800 shadow-md shadow-blue-500/20 px-5 py-2.5",
    secondary: "bg-slate-100 text-slate-800 border border-slate-200 hover:bg-slate-200 px-5 py-2.5",
    success: "bg-gradient-to-br from-emerald-500 to-green-600 text-white hover:from-emerald-600 hover:to-green-700 shadow-md shadow-emerald-500/20 px-5 py-2.5",
    danger: "bg-gradient-to-br from-red-500 to-rose-600 text-white hover:from-red-600 hover:to-rose-700 shadow-md shadow-red-500/20 px-5 py-2.5",
    icon: "p-2 rounded-lg bg-slate-100 text-slate-600 hover:bg-slate-200",
    iconDanger: "p-2 rounded-lg bg-red-50 text-red-600 hover:bg-red-100",
  };

  return (
    <button className={`${baseStyle} ${variants[variant]} ${className}`} {...props}>
      {children}
    </button>
  );
}
