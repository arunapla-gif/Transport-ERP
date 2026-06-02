import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { Wallet, PlusCircle, CheckCircle, Search, ArrowUpRight, ArrowDownRight, Trash2 } from 'lucide-react';

export default function DailyAccounts() {
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [form, setForm] = useState({
    type: 'EXPENSE',
    category: 'Fuel',
    amount: '',
    paymentMode: 'Cash',
    description: '',
    reference: '',
    date: new Date().toISOString().split('T')[0]
  });

  const categories = {
    EXPENSE: ['Fuel', 'Office Supplies', 'Tea/Snacks', 'Maintenance', 'Salary', 'Rent', 'Travel', 'Other'],
    INCOME:  ['Miscellaneous Income', 'Scrap Sale', 'Other']
  };

  useEffect(() => {
    fetchTransactions();
  }, []);

  const fetchTransactions = async () => {
    try {
      setLoading(true);
      const res = await api.get('/daily-transactions');
      setTransactions(Array.isArray(res) ? res : []);
    } catch (err) {
      setError('Failed to fetch daily accounts');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.amount || parseFloat(form.amount) <= 0) return setError('Enter a valid amount');
    
    try {
      setLoading(true);
      await api.post('/daily-transactions', form);
      setSuccess('Transaction recorded successfully!');
      
      setForm(prev => ({
        ...prev,
        amount: '',
        description: '',
        reference: ''
      }));
      
      fetchTransactions();
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError('Failed to record transaction');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this transaction?')) return;
    try {
      await api.delete(`/daily-transactions/${id}`);
      fetchTransactions();
    } catch (err) {
      setError('Failed to delete transaction');
    }
  };

  const totalIncome = transactions.filter(t => t.type === 'INCOME').reduce((sum, t) => sum + t.amount, 0);
  const totalExpense = transactions.filter(t => t.type === 'EXPENSE').reduce((sum, t) => sum + t.amount, 0);
  const netBalance = totalIncome - totalExpense;

  return (
    <div className="max-w-6xl mx-auto space-y-6 pb-10 pt-4" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      <div className="flex items-center gap-3 mb-8">
        <div className="bg-sky-100 text-sky-700 p-2.5 rounded-xl shadow-sm">
          <Wallet size={24} />
        </div>
        <div>
          <h1 className="text-2xl font-black text-slate-800 tracking-tight">Daily Accounts</h1>
          <p className="text-sm font-medium text-slate-500">Track day-to-day operating expenses and miscellaneous income.</p>
        </div>
      </div>

      {error && <div className="bg-rose-50 text-rose-600 p-4 rounded-xl text-sm font-bold border border-rose-200">{error}</div>}
      {success && <div className="bg-emerald-50 text-emerald-600 p-4 rounded-xl text-sm font-bold border border-emerald-200 flex items-center gap-2"><CheckCircle size={16}/> {success}</div>}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Form */}
        <div className="lg:col-span-4">
          <div className="bg-white/80 backdrop-blur-xl border border-slate-200/60 rounded-2xl p-5 shadow-sm sticky top-6">
            <h2 className="text-lg font-black text-slate-800 mb-6 flex items-center gap-2">
              <span className="w-6 h-6 rounded-md bg-sky-100 text-sky-700 flex items-center justify-center text-xs">1</span> 
              New Entry
            </h2>
            
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="flex bg-slate-100 p-1 rounded-xl">
                <button 
                  type="button"
                  onClick={() => setForm({...form, type: 'EXPENSE', category: 'Fuel'})}
                  className={`flex-1 py-2 text-sm font-black rounded-lg transition-colors ${form.type === 'EXPENSE' ? 'bg-white text-rose-600 shadow-sm' : 'text-slate-500'}`}
                >
                  Expense
                </button>
                <button 
                  type="button"
                  onClick={() => setForm({...form, type: 'INCOME', category: 'Miscellaneous Income'})}
                  className={`flex-1 py-2 text-sm font-black rounded-lg transition-colors ${form.type === 'INCOME' ? 'bg-white text-emerald-600 shadow-sm' : 'text-slate-500'}`}
                >
                  Income
                </button>
              </div>

              <div>
                <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 block">Category</label>
                <select 
                  value={form.category} 
                  onChange={e => setForm({...form, category: e.target.value})}
                  className="w-full h-11 px-3 bg-white border border-slate-200 rounded-lg text-sm font-bold text-slate-700 focus:border-sky-500 focus:outline-none"
                >
                  {categories[form.type].map(cat => <option key={cat} value={cat}>{cat}</option>)}
                </select>
              </div>

              <div>
                <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 block">Amount</label>
                <div className="relative">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 font-bold">₹</span>
                  <input 
                    type="number" 
                    value={form.amount} 
                    onChange={e => setForm({...form, amount: e.target.value})}
                    placeholder="0.00"
                    className="w-full h-11 pl-8 pr-3 bg-white border border-slate-200 rounded-lg text-lg font-black text-slate-800 focus:border-sky-500 focus:ring-2 focus:ring-sky-500/20 outline-none" 
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 block">Date</label>
                  <input 
                    type="date" 
                    value={form.date} 
                    onChange={e => setForm({...form, date: e.target.value})}
                    className="w-full h-10 px-3 bg-white border border-slate-200 rounded-lg text-sm font-bold text-slate-700 focus:outline-none focus:border-sky-500" 
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 block">Mode</label>
                  <select 
                    value={form.paymentMode} 
                    onChange={e => setForm({...form, paymentMode: e.target.value})}
                    className="w-full h-10 px-3 bg-white border border-slate-200 rounded-lg text-sm font-bold text-slate-700 focus:outline-none focus:border-sky-500" 
                  >
                    <option value="Cash">Cash</option>
                    <option value="Bank Transfer">Bank</option>
                    <option value="UPI">UPI</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 block">Description</label>
                <input 
                  type="text" 
                  value={form.description} 
                  onChange={e => setForm({...form, description: e.target.value})}
                  placeholder="What was this for?"
                  className="w-full h-10 px-3 bg-white border border-slate-200 rounded-lg text-sm font-medium text-slate-700 focus:outline-none focus:border-sky-500" 
                />
              </div>

              <button 
                type="submit"
                disabled={loading}
                className="w-full h-12 mt-4 bg-sky-600 hover:bg-sky-500 disabled:bg-sky-300 text-white rounded-xl font-black shadow-[0_4px_15px_rgba(2,132,199,0.3)] transition-all flex items-center justify-center gap-2"
              >
                <PlusCircle size={18} /> Save Entry
              </button>
            </form>
          </div>
        </div>

        {/* Right Column: Ledger & Stats */}
        <div className="lg:col-span-8 space-y-6">
          {/* Stats Bar */}
          <div className="grid grid-cols-3 gap-4">
            <div className="bg-white border border-slate-200/60 rounded-2xl p-4 shadow-sm flex items-center gap-4">
               <div className="w-10 h-10 rounded-full bg-emerald-100 flex items-center justify-center text-emerald-600">
                 <ArrowDownRight size={20} />
               </div>
               <div>
                 <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Total Income</div>
                 <div className="text-xl font-black text-slate-800">₹{totalIncome.toFixed(2)}</div>
               </div>
            </div>
            <div className="bg-white border border-slate-200/60 rounded-2xl p-4 shadow-sm flex items-center gap-4">
               <div className="w-10 h-10 rounded-full bg-rose-100 flex items-center justify-center text-rose-600">
                 <ArrowUpRight size={20} />
               </div>
               <div>
                 <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Total Expense</div>
                 <div className="text-xl font-black text-slate-800">₹{totalExpense.toFixed(2)}</div>
               </div>
            </div>
            <div className={`border rounded-2xl p-4 shadow-sm flex flex-col justify-center ${netBalance >= 0 ? 'bg-sky-50 border-sky-200' : 'bg-orange-50 border-orange-200'}`}>
               <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Net Balance</div>
               <div className={`text-2xl font-black ${netBalance >= 0 ? 'text-sky-700' : 'text-orange-600'}`}>
                 ₹{Math.abs(netBalance).toFixed(2)}
               </div>
            </div>
          </div>

          {/* Ledger Table */}
          <div className="bg-white/80 backdrop-blur-xl border border-slate-200/60 rounded-2xl shadow-sm overflow-hidden min-h-[400px]">
             <div className="p-4 border-b border-slate-100 bg-slate-50/50">
               <h2 className="text-sm font-black text-slate-800">Recent Transactions</h2>
             </div>
             
             {transactions.length === 0 ? (
               <div className="flex flex-col items-center justify-center text-slate-400 p-10 h-[300px]">
                 <p className="font-medium text-sm">No transactions recorded yet.</p>
               </div>
             ) : (
               <div className="overflow-x-auto">
                 <table className="w-full text-left border-collapse">
                   <thead>
                     <tr className="bg-slate-50 border-b border-slate-200">
                       <th className="px-5 py-3 text-[10px] font-black text-slate-500 uppercase tracking-wider">Date</th>
                       <th className="px-5 py-3 text-[10px] font-black text-slate-500 uppercase tracking-wider">Details</th>
                       <th className="px-5 py-3 text-[10px] font-black text-slate-500 uppercase tracking-wider">Mode</th>
                       <th className="px-5 py-3 text-[10px] font-black text-slate-500 uppercase tracking-wider text-right">Amount</th>
                       <th className="px-5 py-3 w-10"></th>
                     </tr>
                   </thead>
                   <tbody>
                     {transactions.map(t => (
                       <tr key={t.id} className="border-b border-slate-100 hover:bg-slate-50/50 transition-colors">
                         <td className="px-5 py-3 text-xs font-bold text-slate-600 whitespace-nowrap">
                           {new Date(t.date).toLocaleDateString()}
                         </td>
                         <td className="px-5 py-3">
                           <div className="flex items-center gap-2">
                             <span className={`px-2 py-0.5 rounded text-[10px] font-black uppercase ${t.type === 'INCOME' ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'}`}>
                               {t.category}
                             </span>
                           </div>
                           {t.description && <div className="text-xs font-medium text-slate-500 mt-1">{t.description}</div>}
                         </td>
                         <td className="px-5 py-3 text-xs font-bold text-slate-600">
                           {t.paymentMode}
                         </td>
                         <td className="px-5 py-3 text-right">
                           <span className={`text-sm font-black ${t.type === 'INCOME' ? 'text-emerald-600' : 'text-rose-600'}`}>
                             {t.type === 'INCOME' ? '+' : '-'} ₹{t.amount.toFixed(2)}
                           </span>
                         </td>
                         <td className="px-5 py-3 text-right">
                           <button onClick={() => handleDelete(t.id)} className="text-slate-300 hover:text-rose-500 transition-colors">
                             <Trash2 size={16} />
                           </button>
                         </td>
                       </tr>
                     ))}
                   </tbody>
                 </table>
               </div>
             )}
          </div>
        </div>
      </div>
    </div>
  );
}
