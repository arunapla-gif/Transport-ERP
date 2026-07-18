import React, { useState } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { QrCode, Phone, ShieldCheck } from 'lucide-react';

export default function QrDemo() {
  const [amount, setAmount] = useState('');
  
  // The VPA provided by the user
  const vpa = 'arun.apla-1@okaxis';
  const payeeName = 'Arun Transport';
  
  // Build the standard UPI URI.
  // If amount is provided, append it to make it a Dynamic QR. Otherwise it's Static.
  let upiString = `upi://pay?pa=${vpa}&pn=${encodeURIComponent(payeeName)}`;
  if (amount && !isNaN(amount) && Number(amount) > 0) {
    upiString += `&am=${amount}`;
  }

  return (
    <div className="max-w-2xl mx-auto mt-10 p-6 bg-white rounded-3xl shadow-xl border border-slate-100 flex flex-col items-center">
      <div className="w-16 h-16 bg-indigo-100 text-indigo-600 rounded-2xl flex items-center justify-center mb-4 shadow-inner">
        <QrCode size={32} />
      </div>
      
      <h2 className="text-2xl font-black text-slate-800 mb-2 text-center">Scan to Pay</h2>
      <p className="text-slate-500 font-medium mb-8 text-center max-w-sm">
        Scan this QR code with any UPI app (GPay, PhonePe, Paytm, etc.) to securely test the payment flow.
      </p>

      {/* QR Code Container */}
      <div className="p-4 bg-white rounded-3xl shadow-md border-4 border-slate-50 mb-6">
        <QRCodeSVG 
          value={upiString} 
          size={250} 
          level="H" 
          includeMargin={true}
          fgColor="#1e293b" // slate-800
        />
      </div>

      <div className="flex items-center gap-2 text-emerald-600 font-bold mb-8 bg-emerald-50 px-4 py-2 rounded-full">
        <ShieldCheck size={18} />
        <span>Verified VPA: {vpa}</span>
      </div>

      {/* Dynamic Amount Tester */}
      <div className="w-full bg-slate-50 p-6 rounded-2xl border border-slate-200">
        <h3 className="text-lg font-black text-slate-800 mb-2">Test Dynamic Amount (Optional)</h3>
        <p className="text-xs font-semibold text-slate-500 mb-4">
          Enter an amount below to lock it into the QR code. When you scan it, the app will have the amount pre-filled! Leave empty for a static QR.
        </p>
        
        <div className="flex items-center gap-3">
          <div className="relative flex-1">
            <span className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 font-bold">₹</span>
            <input 
              type="number"
              placeholder="e.g. 500"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="w-full h-12 pl-10 pr-4 bg-white border border-slate-300 rounded-xl font-bold text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 transition-all"
            />
          </div>
          <button 
            onClick={() => setAmount('')}
            className="h-12 px-6 bg-slate-200 hover:bg-slate-300 text-slate-700 font-bold rounded-xl transition-colors"
          >
            Clear
          </button>
        </div>
      </div>
      
      <div className="mt-8 flex items-center justify-center gap-6 opacity-50 grayscale">
         <div className="text-xs font-black text-slate-500 flex items-center gap-1"><Phone size={14} /> GPay</div>
         <div className="text-xs font-black text-slate-500 flex items-center gap-1"><Phone size={14} /> PhonePe</div>
         <div className="text-xs font-black text-slate-500 flex items-center gap-1"><Phone size={14} /> Paytm</div>
      </div>
    </div>
  );
}
