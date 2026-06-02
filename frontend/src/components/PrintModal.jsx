import React, { useState } from 'react';
import { X, Printer, FileText, PackageCheck } from 'lucide-react';

export default function PrintModal({ isOpen, onClose }) {
  const [gcNumber, setGcNumber] = useState('');
  const [gdmNumber, setGdmNumber] = useState('');

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-slate-900/40 backdrop-blur-sm transition-opacity" 
        onClick={onClose}
      />
      
      {/* Modal */}
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
        
        {/* Header */}
        <div className="px-6 py-4 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
          <div className="flex items-center gap-2">
            <div className="bg-indigo-100 text-indigo-600 p-1.5 rounded-lg">
              <Printer size={18} />
            </div>
            <h2 className="text-lg font-black text-slate-800">Quick Print</h2>
          </div>
          <button 
            onClick={onClose}
            className="p-2 text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-full transition-colors"
          >
            <X size={20} />
          </button>
        </div>

        {/* Body */}
        <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-6 bg-white">
          
          {/* LORRY RECEIPT */}
          <div className="bg-slate-50 rounded-xl border border-slate-200 p-5 flex flex-col items-center text-center">
            <div className="w-12 h-12 bg-amber-100 text-amber-600 rounded-full flex items-center justify-center mb-3 shadow-sm">
              <FileText size={24} />
            </div>
            <h3 className="font-bold text-slate-800 mb-1">Lorry Receipt</h3>
            <p className="text-xs text-slate-500 mb-4 font-medium">Print A5 Receipt</p>
            
            <div className="w-full flex gap-2">
              <input 
                type="text" 
                placeholder="e.g. BELL-1001" 
                value={gcNumber}
                onChange={(e) => setGcNumber(e.target.value.toUpperCase())}
                className="flex-1 h-10 px-3 bg-white border border-slate-200 text-slate-800 font-bold text-sm rounded-lg focus:outline-none focus:ring-2 focus:ring-amber-500/20 focus:border-amber-500 uppercase"
              />
              <button 
                onClick={() => {
                  if (gcNumber) window.open(`/print/gc/${gcNumber}`, '_blank');
                }}
                disabled={!gcNumber}
                className={`h-10 px-4 flex items-center justify-center gap-2 bg-amber-500 text-white font-bold text-sm rounded-lg transition-all ${!gcNumber ? 'opacity-50 cursor-not-allowed' : 'hover:bg-amber-400 shadow-sm hover:shadow'}`}
              >
                Print
              </button>
            </div>
          </div>

          {/* DELIVERY MEMO */}
          <div className="bg-slate-50 rounded-xl border border-slate-200 p-5 flex flex-col items-center text-center">
            <div className="w-12 h-12 bg-emerald-100 text-emerald-600 rounded-full flex items-center justify-center mb-3 shadow-sm">
              <PackageCheck size={24} />
            </div>
            <h3 className="font-bold text-slate-800 mb-1">Delivery Memo</h3>
            <p className="text-xs text-slate-500 mb-4 font-medium">Print A4 GDM</p>
            
            <div className="w-full flex gap-2">
              <input 
                type="text" 
                placeholder="e.g. 1001" 
                value={gdmNumber}
                onChange={(e) => setGdmNumber(e.target.value)}
                className="flex-1 h-10 px-3 bg-white border border-slate-200 text-slate-800 font-bold text-sm rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 uppercase"
              />
              <button 
                onClick={() => {
                  if (gdmNumber) window.open(`/print/gdm/${gdmNumber}`, '_blank');
                }}
                disabled={!gdmNumber}
                className={`h-10 px-4 flex items-center justify-center gap-2 bg-emerald-600 text-white font-bold text-sm rounded-lg transition-all ${!gdmNumber ? 'opacity-50 cursor-not-allowed' : 'hover:bg-emerald-500 shadow-sm hover:shadow'}`}
              >
                Print
              </button>
            </div>
          </div>

        </div>
      </div>
    </div>
  );
}
