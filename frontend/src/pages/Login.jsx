import React, { useState, useEffect } from 'react';
import { Lock, UserCircle, Truck, ArrowLeft } from 'lucide-react';
import { API_BASE } from '../api';
import { Button } from '../components/ui/Button';

export default function Login({ onLogin }) {
  const [users, setUsers] = useState([]);
  const [selectedUser, setSelectedUser] = useState(null);
  const [pin, setPin] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [fetchingUsers, setFetchingUsers] = useState(true);

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      setFetchingUsers(true);
      const res = await fetch(`${API_BASE}/public/users`, {
        headers: { 'Bypass-Tunnel-Reminder': 'true' }
      });
      if (res.ok) {
        const data = await res.json();
        // Add the fallback System Admin
        data.push({ id: 'admin', username: 'System Admin', role: 'admin', branch: 'ALL' });
        setUsers(data);
      }
    } catch (err) {
      setError('Connection error. Is the server running?');
    } finally {
      setFetchingUsers(false);
    }
  };

  const handleUserSelect = (user) => {
    if (window.navigator && window.navigator.vibrate) window.navigator.vibrate(20);
    setSelectedUser(user);
    setPin('');
    setError('');
  };

  const handleBackToUsers = () => {
    setSelectedUser(null);
    setPin('');
    setError('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (pin.length !== 4 || !selectedUser) return;
    
    setLoading(true);
    try {
      const res = await fetch(`${API_BASE}/login`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true'
        },
        body: JSON.stringify({ userId: selectedUser.id, pin })
      });
      
      const data = await res.json();
      
      if (!res.ok) {
        setError(data.error || 'Invalid PIN code. Please try again.');
        setPin('');
      } else {
        localStorage.setItem('erp_token', data.token);
        localStorage.setItem('erp_permissions', JSON.stringify(data.permissions || { create: true, edit: true, delete: false, reports: false }));
        localStorage.setItem('assignedBranch', data.branch);
        localStorage.setItem('activeBranch', data.branch === 'ALL' ? 'MAIN' : data.branch); 
        onLogin(data.role);
      }
    } catch (err) {
      setError('Connection error. Is the server running?');
      setPin('');
    } finally {
      setLoading(false);
    }
  };

  const handleKeyPress = (digit) => {
    if (window.navigator && window.navigator.vibrate) window.navigator.vibrate(40);
    if (pin.length < 4) {
      setPin(prev => prev + digit);
      setError('');
    }
  };

  const handleDelete = () => {
    if (window.navigator && window.navigator.vibrate) window.navigator.vibrate(40);
    setPin(prev => prev.slice(0, -1));
  };

  return (
    <div className="min-h-screen bg-stone-950 flex flex-col items-center justify-center p-4 selection:bg-stone-700">
      <div className="max-w-xl w-full">
        {/* Logo Header */}
        <div className="text-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-indigo-500 to-indigo-700 mx-auto flex items-center justify-center mb-4 shadow-[0_0_40px_rgba(99,102,241,0.4)]">
            <Truck size={32} className="text-white" />
          </div>
          <h1 className="text-3xl font-black tracking-tight text-white mb-2">Transport ERP</h1>
          <p className="text-stone-400 font-medium text-sm">Enterprise Authentication</p>
        </div>

        {/* Login Card */}
        <div className="bg-stone-900 rounded-3xl p-6 md:p-8 shadow-2xl border border-stone-800">
          
          {!selectedUser ? (
            // STEP 1: SELECT USER
            <div className="animate-in fade-in slide-in-from-bottom-4 duration-300">
              <h2 className="text-xl font-bold text-white text-center mb-6">Select your profile</h2>
              
              {fetchingUsers ? (
                <div className="flex justify-center p-8"><div className="w-8 h-8 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin"></div></div>
              ) : error ? (
                <div className="text-rose-400 text-sm font-bold text-center mb-4">{error}</div>
              ) : (
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 max-h-[50vh] overflow-y-auto pr-2 custom-scrollbar">
                  {users.map(u => (
                    <button
                      key={u.id}
                      onClick={() => handleUserSelect(u)}
                      className="bg-stone-800 hover:bg-stone-700 active:scale-95 transition-all p-4 rounded-2xl border border-stone-700 flex flex-col items-center gap-3 text-center touch-manipulation group"
                    >
                      <div className={`w-12 h-12 rounded-full flex items-center justify-center ${u.role === 'admin' ? 'bg-amber-500/20 text-amber-400' : 'bg-indigo-500/20 text-indigo-400'} group-hover:scale-110 transition-transform`}>
                        <UserCircle size={28} />
                      </div>
                      <div>
                        <div className="text-white font-bold text-sm truncate w-full px-1">{u.username}</div>
                        <div className="text-stone-400 text-[10px] uppercase tracking-wider font-bold">{u.role}</div>
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </div>
          ) : (
            // STEP 2: ENTER PIN
            <div className="animate-in fade-in slide-in-from-right-4 duration-300">
              <button 
                onClick={handleBackToUsers}
                className="flex items-center gap-2 text-stone-400 hover:text-white font-bold text-sm transition-colors mb-6 active:scale-95 touch-manipulation"
              >
                <ArrowLeft size={16} /> Back to Users
              </button>

              <div className="flex flex-col items-center mb-8">
                <div className={`w-16 h-16 rounded-full flex items-center justify-center mb-3 ${selectedUser.role === 'admin' ? 'bg-amber-500/20 text-amber-400' : 'bg-indigo-500/20 text-indigo-400'}`}>
                  <UserCircle size={36} />
                </div>
                <h2 className="text-xl font-bold text-white text-center">Hi, {selectedUser.username}</h2>
                <p className="text-stone-400 text-sm font-medium">Enter your 4-digit PIN</p>
              </div>
              
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
                    <Button variant="custom"
                      key={digit}
                      type="button"
                      onClick={() => handleKeyPress(digit.toString())}
                      className="h-14 bg-stone-950 rounded-2xl text-xl font-bold text-white hover:bg-stone-800 transition-colors border border-stone-800 shadow-sm active:scale-95 touch-manipulation select-none"
                    >
                      {digit}
                    </Button>
                  ))}
                  <div className="h-14"></div>
                  <Button variant="custom"
                    type="button"
                    onClick={() => handleKeyPress('0')}
                    className="h-14 bg-stone-950 rounded-2xl text-xl font-bold text-white hover:bg-stone-800 transition-colors border border-stone-800 shadow-sm active:scale-95 touch-manipulation select-none"
                  >
                    0
                  </Button>
                  <Button variant="custom"
                    type="button"
                    onClick={handleDelete}
                    className="h-14 bg-stone-950 rounded-2xl text-lg font-bold text-stone-400 hover:text-white hover:bg-stone-800 transition-colors border border-stone-800 shadow-sm flex items-center justify-center active:scale-95 touch-manipulation select-none"
                  >
                    ⌫
                  </Button>
                </div>

                <Button variant="custom" 
                  type="submit" 
                  className={`w-full py-4 rounded-xl font-black text-lg transition-all ${pin.length === 4 ? 'bg-indigo-600 text-white hover:bg-indigo-500 shadow-[0_0_20px_rgba(99,102,241,0.4)]' : 'bg-stone-800 text-stone-500 cursor-not-allowed'}`}
                  disabled={pin.length !== 4 || loading}
                >
                  {loading ? 'Authenticating...' : 'Access System'}
                </Button>
              </form>
            </div>
          )}
          
        </div>
      </div>
    </div>
  );
}
