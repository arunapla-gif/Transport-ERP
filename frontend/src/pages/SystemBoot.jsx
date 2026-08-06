import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api';
import { CheckCircle2, Server, Database, KeyRound, ArrowRight, Loader2, AlertCircle, Wifi } from 'lucide-react';
import { usePermissions } from '../hooks/usePermissions';

export default function SystemBoot() {
  const navigate = useNavigate();
  const { isAdmin } = usePermissions();
  const [bootState, setBootState] = useState({
    network: 'pending',
    server: 'pending',   // pending | loading | success | error
    database: 'pending',
    auth: 'pending'
  });
  const [errorMsg, setErrorMsg] = useState(null);

  useEffect(() => {
    let isMounted = true;
    
    const runBootSequence = async () => {
      // Check if already booted in this session to prevent annoying re-animations
      if (sessionStorage.getItem('system_booted') === 'true') {
        // Do NOT optimistically show green! Just do a rapid background check without artificial delays.
        setBootState({ network: 'loading', server: 'loading', database: 'loading', auth: 'loading' });
        
        try {
          if (!navigator.onLine) throw new Error('offline');
          await api.get('/health?_=' + Date.now());
          if (!isMounted) return;
          setBootState({ network: 'success', server: 'success', database: 'success', auth: 'success' });
        } catch (err) {
          if (!isMounted) return;
          // If the real check fails, flip it to red and show the error!
          setBootState(prev => ({ ...prev, network: err.message === 'offline' ? 'error' : 'success', server: 'error', database: 'error' }));
          setErrorMsg(err.message === 'offline' ? 'No Internet Connection!' : 'Background Health Check Failed: System is offline!');
        }
        return;
      }

      // 1. Check Physical Internet Connection
      setBootState(prev => ({ ...prev, network: 'loading' }));
      if (!navigator.onLine) {
        if (!isMounted) return;
        setBootState(prev => ({ ...prev, network: 'error' }));
        setErrorMsg('No Internet Connection. Please check your Wi-Fi or router.');
        return;
      }
      if (!isMounted) return;
      setBootState(prev => ({ ...prev, network: 'success' }));

      // 2. Check Server connection (visual check, real check happens in step 3)
      setBootState(prev => ({ ...prev, server: 'loading' }));
      await new Promise(r => setTimeout(r, 600)); // Artificial delay for polish
      if (!isMounted) return;
      setBootState(prev => ({ ...prev, server: 'success' }));

      // 2. Check Database via /health
      if (!isMounted) return;
      setBootState(prev => ({ ...prev, database: 'loading' }));
      try {
        await api.get('/health?_=' + Date.now());
        if (!isMounted) return;
        setBootState(prev => ({ ...prev, database: 'success' }));
      } catch (err) {
        if (!isMounted) return;
        setBootState(prev => ({ ...prev, database: 'error' }));
        setErrorMsg('Database Timeout');
        return;
      }

      // 3. Check Authentication Keys (Token verification)
      if (!isMounted) return;
      setBootState(prev => ({ ...prev, auth: 'loading' }));
      try {
        const token = localStorage.getItem('erp_token');
        if (!token) throw new Error('No Token');
        // Minor artificial delay for visual polish to show it checked the token
        // Minor artificial delay for visual polish to show it checked the token
        await new Promise(r => setTimeout(r, 600)); 
        
        // Mark as booted for this session
        sessionStorage.setItem('system_booted', 'true');
        
        if (!isMounted) return;
        setBootState(prev => ({ ...prev, auth: 'success' }));
      } catch (err) {
        if (!isMounted) return;
        setBootState(prev => ({ ...prev, auth: 'error' }));
        setErrorMsg('Invalid Session Key');
        return;
      }
    };

    // Run immediately on mount
    runBootSequence();

    // Attach function to window or state so we can call it manually
    window.__retryBootSequence = () => {
      setErrorMsg(null);
      setBootState({ network: 'pending', server: 'pending', database: 'pending', auth: 'pending' });
      sessionStorage.removeItem('system_booted');
      runBootSequence();
    };

    return () => {
      isMounted = false;
      delete window.__retryBootSequence;
    };
  }, []);

  const allReady = bootState.network === 'success' && bootState.server === 'success' && bootState.database === 'success' && bootState.auth === 'success';

  const CheckItem = ({ label, state, icon: Icon }) => {
    return (
      <div className={`flex items-center gap-4 p-4 rounded-xl border ${
        state === 'success' ? 'bg-emerald-50/50 border-emerald-100 text-emerald-700' :
        state === 'error' ? 'bg-rose-50 border-rose-100 text-rose-600' :
        state === 'loading' ? 'bg-blue-50/50 border-blue-100 text-blue-700' :
        'bg-slate-50 border-slate-100 text-slate-400'
      } transition-colors duration-500`}>
        <div className={`p-2 rounded-lg ${
          state === 'success' ? 'bg-emerald-100' :
          state === 'error' ? 'bg-rose-100' :
          state === 'loading' ? 'bg-blue-100 animate-pulse' :
          'bg-slate-200'
        }`}>
          {state === 'loading' ? <Loader2 size={20} className="animate-spin" /> : 
           state === 'success' ? <CheckCircle2 size={20} /> :
           state === 'error' ? <AlertCircle size={20} /> :
           <Icon size={20} />}
        </div>
        <div className="flex-1">
          <p className="font-semibold">{label}</p>
          <p className="text-xs opacity-80">
            {state === 'success' ? 'Connected and Online' :
             state === 'error' ? 'Connection Failed' :
             state === 'loading' ? 'Verifying connection...' :
             'Waiting for sequence...'}
          </p>
        </div>
      </div>
    );
  };

  return (
    <div className={`min-h-[85vh] flex flex-col p-4 ${isAdmin && allReady ? 'max-w-[1400px] mx-auto pt-8' : 'items-center justify-center'}`}>
      


      <div className={`w-full max-w-md ${isAdmin && allReady ? 'mx-auto' : ''}`}>
        
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-indigo-600 text-white shadow-xl shadow-indigo-200 mb-4 relative">
            <Server size={32} />
            <span className="absolute -top-2 -right-12 bg-emerald-500 text-white text-[10px] font-black px-2 py-0.5 rounded-full shadow-lg shadow-emerald-500/30 animate-pulse border border-emerald-400">v3.0.1 Live</span>
          </div>
          <h1 className="text-2xl font-bold text-slate-800">System Dashboard</h1>
          <p className="text-slate-500 mt-1">Initializing Secure Workspace</p>
        </div>

        <div className="space-y-3">
          <CheckItem label="Local Internet Connection" state={bootState.network} icon={Wifi} />
          <CheckItem label="Secure Server Connection" state={bootState.server} icon={Server} />
          <CheckItem label="Core Database Integrity" state={bootState.database} icon={Database} />
          <CheckItem label="Authentication Keys" state={bootState.auth} icon={KeyRound} />
        </div>

        {errorMsg && (
          <div className="mt-6 p-4 rounded-xl bg-rose-50 border border-rose-200 text-rose-600 flex flex-col gap-3">
            <div className="flex items-start gap-3">
              <AlertCircle className="shrink-0 mt-0.5" size={18} />
              <p className="text-sm font-medium">{errorMsg}. Please check your connection.</p>
            </div>
            <button 
              onClick={() => window.__retryBootSequence && window.__retryBootSequence()}
              className="mt-1 py-2 px-4 bg-white/50 hover:bg-white rounded-lg border border-rose-200 font-bold text-sm transition-colors w-fit shadow-sm"
            >
              Retry Connection
            </button>
          </div>
        )}

        {allReady && (
          <div className="mt-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
            {localStorage.getItem('assignedBranch') === 'ALL' ? (
              <div className="space-y-4">
                <h2 className="text-center font-bold text-slate-500 mb-2 uppercase tracking-widest text-xs">Select Operating Branch</h2>
                <div className="grid grid-cols-2 gap-4">
                  <button
                    onClick={() => {
                      localStorage.setItem('activeBranch', 'MAIN');
                      navigate('/new-gc');
                    }}
                    className="p-6 rounded-2xl bg-indigo-50 border-2 border-indigo-100 hover:border-indigo-500 hover:bg-indigo-600 hover:text-white group transition-all duration-300 shadow-sm hover:shadow-xl hover:shadow-indigo-200/50 flex flex-col items-center justify-center gap-2"
                  >
                    <Database size={28} className="text-indigo-500 group-hover:text-indigo-200 transition-colors" />
                    <span className="font-black text-lg text-indigo-900 group-hover:text-white transition-colors">MAIN BRANCH</span>
                  </button>
                  <button
                    onClick={() => {
                      localStorage.setItem('activeBranch', 'AP_BNG');
                      navigate('/new-gc');
                    }}
                    className="p-6 rounded-2xl bg-amber-50 border-2 border-amber-100 hover:border-amber-500 hover:bg-amber-500 hover:text-white group transition-all duration-300 shadow-sm hover:shadow-xl hover:shadow-amber-200/50 flex flex-col items-center justify-center gap-2"
                  >
                    <Server size={28} className="text-amber-600 group-hover:text-amber-100 transition-colors" />
                    <span className="font-black text-lg text-amber-900 group-hover:text-white transition-colors">AP BNG</span>
                  </button>
                </div>
              </div>
            ) : (
              <button
                onClick={() => navigate('/new-gc')}
                className="w-full py-4 px-6 rounded-xl font-bold text-lg flex items-center justify-center gap-2 transition-all duration-300 bg-slate-900 text-white shadow-xl shadow-slate-200 hover:bg-indigo-600 hover:shadow-indigo-200 hover:-translate-y-0.5"
              >
                Proceed to Operations
                <ArrowRight size={20} className="animate-pulse" />
              </button>
            )}
          </div>
        )}

        {!allReady && (
          <div className="mt-8">
            <button disabled className="w-full py-4 px-6 rounded-xl font-bold text-lg flex items-center justify-center gap-2 transition-all duration-300 bg-slate-100 text-slate-400 cursor-not-allowed">
              Awaiting System Readiness
            </button>
          </div>
        )}

      </div>
    </div>
  );
}
