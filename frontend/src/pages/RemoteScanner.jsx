import React, { useState, useEffect } from 'react';
import { api } from '../api';
import ScannerModal from '../components/ui/ScannerModal';
import { Smartphone, CheckCircle2, QrCode } from 'lucide-react';

export default function RemoteScanner() {
  const [code, setCode] = useState('');
  const [isLinked, setIsLinked] = useState(false);
  const [isScannerOpen, setIsScannerOpen] = useState(false);
  const [lastScanned, setLastScanned] = useState('');
  const [status, setStatus] = useState('waiting'); // waiting, success, error

  useEffect(() => {
    // Dynamically change the App Icon and Title for this specific route!
    const appleIcon = document.getElementById('dynamic-apple-icon');
    const appTitle = document.getElementById('dynamic-app-title');
    if (appleIcon) appleIcon.href = '/scanner-icon.png';
    if (appTitle) appTitle.content = 'ERP Scanner';

    return () => {
      // Revert back when leaving (though usually PWA installs don't trigger cleanup like this)
      if (appleIcon) appleIcon.href = '/erp-icon.png';
      if (appTitle) appTitle.content = 'Transport ERP';
    };
  }, []);

  const handleLink = (e) => {
    e.preventDefault();
    if (code.length === 4) {
      setIsLinked(true);
      setIsScannerOpen(true);
    }
  };

  const handleScan = async (scannedText) => {
    setIsScannerOpen(false);
    setStatus('pushing');
    
    try {
      await api.post('/scanner/push', { code, data: scannedText });
      setLastScanned(scannedText);
      setStatus('success');
      
      // Auto reopen scanner after 2 seconds for continuous scanning
      setTimeout(() => {
        setStatus('waiting');
        setIsScannerOpen(true);
      }, 2000);
      
    } catch (err) {
      setStatus('error');
      console.error(err);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 p-6 flex flex-col items-center justify-center font-sans">
      <div className="w-full max-w-sm bg-white rounded-3xl shadow-xl border border-slate-100 p-8 text-center">
        
        <div className="w-16 h-16 bg-indigo-100 text-indigo-600 rounded-2xl flex items-center justify-center mx-auto mb-6 shadow-inner">
          <Smartphone size={32} />
        </div>
        
        <h1 className="text-2xl font-black text-slate-800 mb-2">Remote Scanner</h1>
        <p className="text-sm font-bold text-slate-500 mb-8">Use your phone to scan E-Way Bills directly into the PC.</p>

        {!isLinked ? (
          <form onSubmit={handleLink} className="space-y-6">
            <div>
              <label className="text-xs font-bold text-slate-400 uppercase tracking-wider block mb-2">Enter 4-Digit PC Code</label>
              <input 
                type="text" 
                maxLength={4}
                value={code}
                onChange={e => setCode(e.target.value.replace(/\D/g, ''))}
                className="w-full text-center text-4xl font-black tracking-[0.5em] h-20 bg-slate-50 border-2 border-slate-200 rounded-2xl focus:border-indigo-500 focus:ring-4 focus:ring-indigo-500/20 outline-none transition-all"
                placeholder="0000"
                inputMode="numeric"
                autoFocus
              />
            </div>
            <button 
              disabled={code.length !== 4}
              type="submit"
              className="w-full h-14 bg-indigo-600 hover:bg-indigo-500 disabled:bg-slate-300 disabled:text-slate-500 text-white rounded-xl font-black text-lg shadow-[0_4px_12px_rgba(79,70,229,0.3)] transition-all active:scale-95 flex items-center justify-center gap-2"
            >
              <QrCode size={20} /> Link to PC
            </button>
          </form>
        ) : (
          <div className="space-y-6 animate-in zoom-in duration-300">
            {status === 'success' ? (
              <div className="py-8">
                <CheckCircle2 size={64} className="text-emerald-500 mx-auto mb-4 animate-bounce" />
                <h2 className="text-xl font-black text-emerald-600">Sent to PC!</h2>
                <p className="text-sm font-bold text-slate-500 mt-2">{lastScanned}</p>
              </div>
            ) : status === 'pushing' ? (
              <div className="py-8">
                <div className="w-12 h-12 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin mx-auto mb-4" />
                <h2 className="text-lg font-bold text-indigo-600">Syncing...</h2>
              </div>
            ) : (
              <div className="py-8">
                <h2 className="text-lg font-black text-indigo-600">Linked to PC: #{code}</h2>
                <p className="text-sm font-bold text-slate-500 mt-2 mb-6">Scanner is opening...</p>
                
                <button 
                  onClick={() => setIsScannerOpen(true)}
                  className="w-full h-14 bg-emerald-600 text-white rounded-xl font-black text-lg shadow-[0_4px_12px_rgba(16,185,129,0.3)] transition-all active:scale-95"
                >
                  Open Camera Manually
                </button>
              </div>
            )}
            
            <button 
              onClick={() => { setIsLinked(false); setCode(''); }}
              className="text-sm font-bold text-slate-400 hover:text-slate-600"
            >
              Disconnect
            </button>
          </div>
        )}
      </div>

      <ScannerModal 
        isOpen={isScannerOpen} 
        onClose={() => setIsScannerOpen(false)} 
        onScan={handleScan}
      />
    </div>
  );
}
