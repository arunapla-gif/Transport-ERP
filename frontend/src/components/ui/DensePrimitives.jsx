import React from 'react';

export const DenseInput = React.forwardRef(({ label, error, className = "", ...props }, ref) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className={`text-[11px] font-bold uppercase tracking-wider mb-1 transition-colors ${error ? 'text-rose-600' : 'text-slate-500 group-focus-within:text-indigo-600'}`}>{label}</label>}
    <input 
      ref={ref}
      className={`w-full h-9 px-2.5 rounded-lg bg-white/50 text-sm font-medium focus:outline-none transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] ${error ? 'border-2 border-rose-500 text-rose-700 bg-rose-50/50 focus:border-rose-500 focus:ring-2 focus:ring-rose-500/20' : 'border border-slate-200 text-slate-800 placeholder-slate-400 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300'}`} 
      {...props} 
    />
  </div>
));

export const DenseSelect = React.forwardRef(({ label, error, options, className = "", ...props }, ref) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className={`text-[11px] font-bold uppercase tracking-wider mb-1 transition-colors ${error ? 'text-rose-600' : 'text-slate-500 group-focus-within:text-indigo-600'}`}>{label}</label>}
    <select 
      ref={ref}
      className={`w-full h-9 px-2.5 rounded-lg bg-white/50 text-sm font-medium appearance-none cursor-pointer focus:outline-none transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] ${error ? 'border-2 border-rose-500 text-rose-700 bg-rose-50/50 focus:border-rose-500 focus:ring-2 focus:ring-rose-500/20' : 'border border-slate-200 text-slate-800 focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300'}`} 
      {...props}
    >
      {options.map((opt, i) => (
        <option key={i} value={opt.value || (typeof opt === 'string' ? opt : '')}>{opt.label || (typeof opt === 'string' ? opt : '')}</option>
      ))}
    </select>
  </div>
));

export const denseSearchableSelectClass = "[&>label]:!text-[11px] [&>label]:!font-bold [&>label]:!text-slate-500 [&>label]:!mb-1 [&>div:nth-of-type(1)]:!h-9 [&>div:nth-of-type(1)]:!min-h-0 [&>div:nth-of-type(1)]:!py-0 [&>div:nth-of-type(1)]:!rounded-lg [&>div:nth-of-type(1)]:!border-slate-200 [&>div:nth-of-type(1)]:!bg-white/50 [&>div:nth-of-type(1)]:!shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] [&>div:nth-of-type(1):focus-within]:!border-indigo-500 [&>div:nth-of-type(1):focus-within]:!ring-2 [&>div:nth-of-type(1):focus-within]:!ring-indigo-500/20 [&>div:nth-of-type(1)>input]:!text-sm [&>div:nth-of-type(1)>input]:!font-medium [&>div:nth-of-type(1)>input]:!text-slate-800 [&>div:nth-of-type(1)>div]:!text-sm [&>div:nth-of-type(1)>div]:!font-medium [&>div:nth-of-type(1)>svg]:!w-4 [&>div:nth-of-type(1)>svg]:!h-4 [&:hover>div:nth-of-type(1)]:!border-slate-300 [&:focus-within>label]:!text-indigo-600 [&>label]:transition-colors";

export const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white border border-slate-200/60 rounded-xl p-3.5 shadow-[0_4px_20px_rgb(79,70,229,0.04)] relative overflow-visible transition-all duration-300 hover:shadow-[0_4px_20px_rgb(79,70,229,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);
