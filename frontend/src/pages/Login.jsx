import React, { useState } from 'react';
import { Lock, UserCircle, Truck } from 'lucide-react';

export default function Login({ onLogin }) {
  const [pin, setPin] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    if (pin === '1234') {
      onLogin('owner');
    } else if (pin === '0000') {
      onLogin('worker');
    } else {
      setError('Invalid PIN code. Please try again.');
      setPin('');
    }
  };

  const handleKeyPress = (digit) => {
    if (pin.length < 4) {
      setPin(prev => prev + digit);
      setError('');
    }
  };

  const handleDelete = () => {
    setPin(prev => prev.slice(0, -1));
  };

  return (
    <div className="min-h-screen bg-stone-900 flex items-center justify-center p-4 selection:bg-stone-700">
      <div className="max-w-md w-full">
        {/* Logo Header */}
        <div className="text-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-indigo-500 to-indigo-700 mx-auto flex items-center justify-center mb-4 shadow-[0_0_40px_rgba(99,102,241,0.4)]">
            <Truck size={32} className="text-white" />
          </div>
          <h1 className="text-3xl font-black tracking-tight text-white mb-2">Transport ERP</h1>
          <p className="text-stone-400 font-medium text-sm">Secure Authentication</p>
        </div>

        {/* Login Card */}
        <div className="bg-stone-800 rounded-3xl p-8 shadow-2xl border border-stone-700">
          <div className="flex justify-center mb-6">
            <div className="bg-stone-900 rounded-full p-4 border border-stone-700 shadow-inner">
              <Lock size={24} className="text-indigo-400" />
            </div>
          </div>

          <h2 className="text-xl font-bold text-white text-center mb-6">Enter Access PIN</h2>
          
          <form onSubmit={handleSubmit}>
            {/* PIN Dots */}
            <div className="flex justify-center gap-4 mb-8">
              {[0, 1, 2, 3].map((index) => (
                <div 
                  key={index} 
                  className={`w-4 h-4 rounded-full transition-all duration-300 ${pin.length > index ? 'bg-indigo-500 scale-110 shadow-[0_0_15px_rgba(99,102,241,0.6)]' : 'bg-stone-700'}`}
                />
              ))}
            </div>

            {error && <div className="text-rose-400 text-sm font-bold text-center mb-4 animate-in fade-in">{error}</div>}

            {/* Numpad */}
            <div className="grid grid-cols-3 gap-3 mb-8 max-w-[280px] mx-auto">
              {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((digit) => (
                <button
                  key={digit}
                  type="button"
                  onClick={() => handleKeyPress(digit.toString())}
                  className="h-14 bg-stone-900 rounded-2xl text-xl font-bold text-white hover:bg-stone-700 transition-colors border border-stone-700/50 shadow-sm active:scale-95"
                >
                  {digit}
                </button>
              ))}
              <div className="h-14"></div>
              <button
                type="button"
                onClick={() => handleKeyPress('0')}
                className="h-14 bg-stone-900 rounded-2xl text-xl font-bold text-white hover:bg-stone-700 transition-colors border border-stone-700/50 shadow-sm active:scale-95"
              >
                0
              </button>
              <button
                type="button"
                onClick={handleDelete}
                className="h-14 bg-stone-900 rounded-2xl text-lg font-bold text-stone-400 hover:text-white hover:bg-stone-700 transition-colors border border-stone-700/50 shadow-sm flex items-center justify-center active:scale-95"
              >
                ⌫
              </button>
            </div>

            <button 
              type="submit" 
              className={`w-full py-4 rounded-xl font-black text-lg transition-all ${pin.length === 4 ? 'bg-indigo-600 text-white hover:bg-indigo-500 shadow-[0_0_20px_rgba(99,102,241,0.4)]' : 'bg-stone-700 text-stone-500 cursor-not-allowed'}`}
              disabled={pin.length !== 4}
            >
              Access System
            </button>
          </form>
          
          <div className="mt-6 pt-6 border-t border-stone-700 text-center flex flex-col gap-1">
             <span className="text-[10px] text-stone-500 font-bold">Owner PIN: 1234</span>
             <span className="text-[10px] text-stone-500 font-bold">Worker PIN: 0000</span>
          </div>
        </div>
      </div>
    </div>
  );
}
