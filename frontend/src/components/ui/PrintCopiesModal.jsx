import React, { useState } from 'react';

export default function PrintCopiesModal({ isOpen, onClose, onConfirm }) {
  const [selectedCopies, setSelectedCopies] = useState(['CONSIGNOR COPY']);

  if (!isOpen) return null;

  const toggleCopy = (copy) => {
    setSelectedCopies(prev => prev.includes(copy) ? prev.filter(c => c !== copy) : [...prev, copy]);
  };

  const handleConfirm = () => {
    if (selectedCopies.length === 0) return;
    onConfirm(selectedCopies);
  };

  return (
    <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-50 flex items-center justify-center print:hidden">
      <div className="bg-white rounded-2xl shadow-xl max-w-sm w-full p-6 m-4 animate-in fade-in zoom-in duration-200">
        <h2 className="text-xl font-black text-slate-800 mb-4 text-center">Print GC Copies</h2>
        <p className="text-sm font-semibold text-slate-500 mb-6 text-center">Select which copies you want to print.</p>
        
        <div className="space-y-3 mb-8">
          {['CONSIGNOR COPY', 'CONSIGNEE COPY', 'LORRY COPY'].map(copy => (
            <label key={copy} className={`flex items-center gap-3 p-3 rounded-xl border-2 cursor-pointer transition-colors ${selectedCopies.includes(copy) ? 'border-indigo-600 bg-indigo-50/50' : 'border-slate-200 hover:border-indigo-300'}`}>
              <input 
                type="checkbox" 
                className="w-5 h-5 rounded text-indigo-600 border-slate-300 focus:ring-indigo-500"
                checked={selectedCopies.includes(copy)}
                onChange={() => toggleCopy(copy)}
              />
              <span className={`font-bold ${selectedCopies.includes(copy) ? 'text-indigo-900' : 'text-slate-600'}`}>{copy}</span>
            </label>
          ))}
        </div>
        
        <div className="flex gap-3">
          <button 
            onClick={onClose}
            className="flex-1 px-4 py-3 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl transition-colors"
          >
            Cancel
          </button>
          <button 
            onClick={handleConfirm}
            disabled={selectedCopies.length === 0}
            className="flex-1 px-4 py-3 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-xl transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center gap-2"
          >
            🖨️ Print
          </button>
        </div>
      </div>
    </div>
  );
}
