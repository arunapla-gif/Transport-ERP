import React from 'react';

export default function TailwindDemo() {
  return (
    <div className="p-8 min-h-[80vh] bg-slate-50 flex items-center justify-center">
      <div className="max-w-md w-full bg-white rounded-3xl shadow-xl overflow-hidden border border-slate-100 transition-all hover:shadow-2xl hover:-translate-y-1 duration-300">
        <div className="bg-gradient-to-br from-blue-600 to-indigo-700 p-6 text-white relative overflow-hidden">
          <div className="absolute top-0 right-0 w-32 h-32 bg-white opacity-10 rounded-full blur-2xl transform translate-x-8 -translate-y-8"></div>
          <h2 className="text-sm font-bold tracking-widest uppercase mb-1 text-blue-100 opacity-90">Tailwind CSS</h2>
          <div className="text-3xl font-extrabold tracking-tight">Premium Card</div>
        </div>
        
        <div className="p-6">
          <p className="text-slate-500 text-sm leading-relaxed mb-6">
            This entire component is built exclusively using Tailwind CSS utility classes. It features responsive design, smooth hover transitions, and complex gradients without writing a single line of custom CSS.
          </p>
          
          <div className="flex flex-col gap-3">
            <div className="flex items-center justify-between p-3 bg-slate-50 rounded-xl border border-slate-100">
              <span className="text-slate-600 text-sm font-medium">Monthly Target</span>
              <span className="text-indigo-600 font-bold bg-indigo-50 px-3 py-1 rounded-full text-xs">85%</span>
            </div>
            <div className="flex items-center justify-between p-3 bg-slate-50 rounded-xl border border-slate-100">
              <span className="text-slate-600 text-sm font-medium">Active Shipments</span>
              <span className="text-emerald-600 font-bold bg-emerald-50 px-3 py-1 rounded-full text-xs">1,204</span>
            </div>
          </div>
          
          <button className="mt-8 w-full bg-slate-900 text-white font-medium py-3 px-4 rounded-xl hover:bg-indigo-600 transition-colors duration-200 shadow-md shadow-indigo-600/20 active:scale-95">
            Confirm Action
          </button>
        </div>
      </div>
    </div>
  );
}
