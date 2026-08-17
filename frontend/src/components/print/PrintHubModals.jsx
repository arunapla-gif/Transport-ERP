import React from 'react';
import { Button } from '../ui/Button';
import { Download, FileText, Zap } from 'lucide-react';

export const PrintCopiesModal = ({
  show,
  onClose,
  selectedCopies,
  toggleCopy,
  handleDownloadPdfGc,
  confirmPrint,
  handleSilentPrintGc,
  isPrinting
}) => {
  if (!show) return null;
  return (
    <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-50 flex items-center justify-center print:hidden p-4">
      <div className="bg-white rounded-2xl shadow-xl max-w-md w-full p-6 animate-in fade-in zoom-in duration-200">
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
        
        <div className="grid grid-cols-2 md:grid-cols-4 gap-2 mt-6">
          <Button variant="custom" 
            onClick={onClose}
            className="px-3 py-2 bg-slate-200 text-slate-800 rounded-lg hover:bg-slate-300 font-bold text-sm flex justify-center items-center"
          >
            Cancel
          </Button>
          <Button variant="custom" 
            onClick={handleDownloadPdfGc}
            disabled={selectedCopies.length === 0 || isPrinting}
            className="px-3 py-2 bg-indigo-100 text-indigo-700 rounded-lg hover:bg-indigo-200 font-bold text-sm flex justify-center items-center gap-1.5 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Download size={16} />
            PDF
          </Button>
          <Button variant="custom" 
            onClick={confirmPrint}
            className="px-3 py-2 bg-slate-600 text-white rounded-lg hover:bg-slate-500 font-bold text-sm flex justify-center items-center gap-1.5"
          >
            <FileText size={16} />
            Preview
          </Button>
          <Button variant="custom" 
            onClick={handleSilentPrintGc}
            disabled={selectedCopies.length === 0 || isPrinting}
            className="px-3 py-2 bg-yellow-500 text-slate-900 rounded-lg hover:bg-yellow-400 font-bold text-sm disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center gap-1.5"
          >
            {isPrinting ? <div className="animate-spin h-4 w-4 border-b-2 border-slate-900 rounded-full"></div> : <Zap size={16} />}
            Print
          </Button>
        </div>
      </div>
    </div>
  );
};

export const PrintFormatModal = ({
  show,
  onClose,
  gdmPrintType,
  setGdmPrintType,
  handleDownloadPdfGdm,
  confirmGdmPrint,
  handleSilentPrintGdm,
  isPrinting
}) => {
  if (!show) return null;
  return (
    <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-50 flex items-center justify-center print:hidden p-4">
      <div className="bg-white rounded-2xl shadow-xl max-w-md w-full p-6 animate-in fade-in zoom-in duration-200">
        <h2 className="text-xl font-black text-slate-800 mb-4 text-center">Select Print Format</h2>
        <p className="text-sm font-semibold text-slate-500 mb-6 text-center">Choose the format for your Delivery Memo.</p>
        
        <div className="space-y-3 mb-8">
          {[
            { id: 'gdm', label: 'Standard GDM' },
            { id: 'cewb', label: 'CEWB Format' },
            { id: 'gdm-combined', label: 'Combined (Both)' }
          ].map(format => (
            <label key={format.id} className={`flex items-center gap-3 p-3 rounded-xl border-2 cursor-pointer transition-colors ${gdmPrintType === format.id ? 'border-emerald-600 bg-emerald-50/50' : 'border-slate-200 hover:border-emerald-300'}`}>
              <input 
                type="radio" 
                name="gdmFormat"
                className="w-5 h-5 text-emerald-600 border-slate-300 focus:ring-emerald-500"
                checked={gdmPrintType === format.id}
                onChange={() => setGdmPrintType(format.id)}
              />
              <span className={`font-bold ${gdmPrintType === format.id ? 'text-emerald-900' : 'text-slate-600'}`}>{format.label}</span>
            </label>
          ))}
        </div>
        
        <div className="grid grid-cols-2 md:grid-cols-4 gap-2 mt-6">
          <Button variant="custom" 
            onClick={onClose}
            className="px-3 py-2 bg-slate-200 text-slate-800 rounded-lg hover:bg-slate-300 font-bold text-sm flex justify-center items-center"
          >
            Cancel
          </Button>
          <Button variant="custom" 
            onClick={handleDownloadPdfGdm}
            disabled={isPrinting}
            className="px-3 py-2 bg-emerald-100 text-emerald-700 rounded-lg hover:bg-emerald-200 font-bold text-sm flex justify-center items-center gap-1.5 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Download size={16} />
            PDF
          </Button>
          <Button variant="custom" 
            onClick={confirmGdmPrint}
            className="px-3 py-2 bg-slate-600 text-white rounded-lg hover:bg-slate-500 font-bold text-sm flex justify-center items-center gap-1.5"
          >
            <FileText size={16} />
            Preview
          </Button>
          <Button variant="custom" 
            onClick={handleSilentPrintGdm}
            disabled={isPrinting}
            className="px-3 py-2 bg-yellow-500 text-slate-900 rounded-lg hover:bg-yellow-400 font-bold text-sm disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center gap-1.5"
          >
            {isPrinting ? <div className="animate-spin h-4 w-4 border-b-2 border-slate-900 rounded-full"></div> : <Zap size={16} />}
            Print
          </Button>
        </div>
      </div>
    </div>
  );
};
