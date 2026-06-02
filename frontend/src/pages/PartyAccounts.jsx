import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { Building2, PlusCircle, CheckCircle, IndianRupee, ArrowDownRight, ArrowUpRight } from 'lucide-react';
import { SearchableSelect } from '../components/ui/SearchableSelect';

export default function PartyAccounts() {
  const [partyType, setPartyType] = useState('Consignee');
  const [parties, setParties] = useState([]);
  const [selectedPartyId, setSelectedPartyId] = useState('');
  
  const [ledgerData, setLedgerData] = useState([]);
  const [currentBalance, setCurrentBalance] = useState(0);

  const [paymentForm, setPaymentForm] = useState({
    amount: '',
    paymentMode: 'Bank Transfer',
    reference: '',
    remarks: '',
    date: new Date().toISOString().split('T')[0]
  });

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Fetch Consignees or Consignors
  useEffect(() => {
    fetchParties();
    setSelectedPartyId('');
    setLedgerData([]);
    setCurrentBalance(0);
  }, [partyType]);

  // Fetch Ledger when Party changes
  useEffect(() => {
    if (selectedPartyId) {
      fetchLedger();
    }
  }, [selectedPartyId]);

  const fetchParties = async () => {
    try {
      const endpoint = partyType === 'Consignee' ? '/consignees' : '/consignors';
      const res = await api.get(endpoint);
      setParties(Array.isArray(res) ? res : []);
    } catch (err) {
      setError(`Failed to load ${partyType}s`);
    }
  };

  const fetchLedger = async () => {
    try {
      setLoading(true);
      const res = await api.get(`/party-ledger/${partyType}/${selectedPartyId}`);
      setLedgerData(res.ledger || []);
      setCurrentBalance(res.currentBalance || 0);
    } catch (err) {
      setError('Failed to load ledger');
    } finally {
      setLoading(false);
    }
  };

  const partyOptions = parties.map(p => ({ value: p.id, label: p.name }));

  const handleRecordPayment = async () => {
    if (!selectedPartyId) return setError('Please select a party first');
    if (!paymentForm.amount || parseFloat(paymentForm.amount) <= 0) return setError('Please enter a valid amount');

    try {
      setLoading(true);
      setError('');
      
      await api.post('/party-payments', {
        partyType,
        partyId: selectedPartyId,
        amount: paymentForm.amount,
        paymentMode: paymentForm.paymentMode,
        reference: paymentForm.reference,
        remarks: paymentForm.remarks,
        date: paymentForm.date
      });
      
      setSuccess('Payment recorded successfully!');
      
      // Reset form
      setPaymentForm({
        amount: '',
        paymentMode: 'Bank Transfer',
        reference: '',
        remarks: '',
        date: new Date().toISOString().split('T')[0]
      });

      // Refresh ledger
      fetchLedger();

      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError(err.message || 'Failed to record payment');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-6xl mx-auto space-y-6 pb-10 pt-4" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      <div className="flex items-center justify-between mb-8">
        <div className="flex items-center gap-3">
          <div className="bg-emerald-100 text-emerald-700 p-2.5 rounded-xl shadow-sm">
            <Building2 size={24} />
          </div>
          <div>
            <h1 className="text-2xl font-black text-slate-800 tracking-tight">Party Accounts</h1>
            <p className="text-sm font-medium text-slate-500">Running ledger for Consignees & Consignors.</p>
          </div>
        </div>

        {/* Party Type Toggle */}
        <div className="bg-slate-100 p-1 rounded-xl flex gap-1">
          <button 
            onClick={() => setPartyType('Consignee')}
            className={`px-4 py-1.5 rounded-lg text-sm font-bold transition-colors ${partyType === 'Consignee' ? 'bg-white text-emerald-700 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}
          >
            Consignees
          </button>
          <button 
            onClick={() => setPartyType('Consignor')}
            className={`px-4 py-1.5 rounded-lg text-sm font-bold transition-colors ${partyType === 'Consignor' ? 'bg-white text-emerald-700 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}
          >
            Consignors
          </button>
        </div>
      </div>

      {error && <div className="bg-rose-50 text-rose-600 p-4 rounded-xl text-sm font-bold border border-rose-200">{error}</div>}
      {success && <div className="bg-emerald-50 text-emerald-600 p-4 rounded-xl text-sm font-bold border border-emerald-200 flex items-center gap-2"><CheckCircle size={16}/> {success}</div>}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        {/* Left Column: Selection & Payment Form */}
        <div className="lg:col-span-4 space-y-6">
          <div className="bg-white/80 backdrop-blur-xl border border-slate-200/60 rounded-2xl p-5 shadow-sm">
            <h2 className="text-lg font-black text-slate-800 mb-4 flex items-center gap-2">
              <span className="w-6 h-6 rounded-md bg-slate-100 text-slate-600 flex items-center justify-center text-xs">1</span> 
              Select {partyType}
            </h2>
            <SearchableSelect 
               label={`${partyType} Name`}
               options={partyOptions}
               value={selectedPartyId}
               onChange={(val) => setSelectedPartyId(val)}
               placeholder={`Search ${partyType}...`}
             />
             
             {selectedPartyId && (
               <div className={`mt-6 p-5 rounded-xl border ${currentBalance > 0 ? 'bg-rose-50 border-rose-100' : 'bg-emerald-50 border-emerald-100'} text-center`}>
                 <div className={`text-xs font-bold uppercase tracking-wider mb-1 ${currentBalance > 0 ? 'text-rose-500' : 'text-emerald-600'}`}>
                   {currentBalance > 0 ? 'They Owe You' : currentBalance < 0 ? 'You Owe Them' : 'Settled Even'}
                 </div>
                 <div className={`text-4xl font-black tracking-tight ${currentBalance > 0 ? 'text-rose-600' : 'text-emerald-700'}`}>
                   ₹ {Math.abs(currentBalance).toFixed(2)}
                 </div>
               </div>
             )}
          </div>

          {selectedPartyId && (
            <div className="bg-emerald-50/50 backdrop-blur-xl border border-emerald-200/60 rounded-2xl p-5 shadow-sm">
              <h2 className="text-lg font-black text-emerald-900 mb-4 flex items-center gap-2">
                <span className="w-6 h-6 rounded-md bg-emerald-100 text-emerald-700 flex items-center justify-center text-xs">2</span> 
                Record Payment Received
              </h2>
              
              <div className="space-y-4">
                <div>
                  <label className="text-[10px] font-bold text-emerald-800 uppercase tracking-wider mb-1 block">Amount</label>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 font-bold">₹</span>
                    <input 
                      type="number" 
                      value={paymentForm.amount} 
                      onChange={e => setPaymentForm({...paymentForm, amount: e.target.value})}
                      placeholder="0.00"
                      className="w-full h-11 pl-8 pr-3 bg-white border border-emerald-200 rounded-lg text-lg font-black text-slate-800 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20" 
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="text-[10px] font-bold text-emerald-800 uppercase tracking-wider mb-1 block">Date</label>
                    <input 
                      type="date" 
                      value={paymentForm.date} 
                      onChange={e => setPaymentForm({...paymentForm, date: e.target.value})}
                      className="w-full h-10 px-3 bg-white border border-emerald-200 rounded-lg text-sm font-bold text-slate-700 focus:outline-none" 
                    />
                  </div>
                  <div>
                    <label className="text-[10px] font-bold text-emerald-800 uppercase tracking-wider mb-1 block">Mode</label>
                    <select 
                      value={paymentForm.paymentMode} 
                      onChange={e => setPaymentForm({...paymentForm, paymentMode: e.target.value})}
                      className="w-full h-10 px-3 bg-white border border-emerald-200 rounded-lg text-sm font-bold text-slate-700 focus:outline-none" 
                    >
                      <option value="Bank Transfer">Bank Transfer</option>
                      <option value="Cash">Cash</option>
                      <option value="Cheque">Cheque</option>
                      <option value="UPI">UPI</option>
                    </select>
                  </div>
                </div>

                <div>
                  <label className="text-[10px] font-bold text-emerald-800 uppercase tracking-wider mb-1 block">Reference / UTR</label>
                  <input 
                    type="text" 
                    value={paymentForm.reference} 
                    onChange={e => setPaymentForm({...paymentForm, reference: e.target.value})}
                    placeholder="e.g. NEFT-12345"
                    className="w-full h-10 px-3 bg-white border border-emerald-200 rounded-lg text-sm font-medium text-slate-700 focus:outline-none" 
                  />
                </div>

                <button 
                  onClick={handleRecordPayment}
                  disabled={loading || !paymentForm.amount}
                  className="w-full h-12 mt-2 bg-emerald-600 hover:bg-emerald-500 disabled:bg-emerald-300 text-white rounded-xl font-black shadow-[0_4px_15px_rgba(5,150,105,0.3)] transition-all flex items-center justify-center gap-2"
                >
                  <PlusCircle size={18} /> Record Payment
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Right Column: Running Ledger */}
        <div className="lg:col-span-8">
           <div className="bg-white/80 backdrop-blur-xl border border-slate-200/60 rounded-2xl shadow-sm overflow-hidden flex flex-col h-full min-h-[600px]">
             <div className="p-5 border-b border-slate-100 flex justify-between items-center bg-slate-50/50">
               <h2 className="text-lg font-black text-slate-800 flex items-center gap-2">
                 <IndianRupee size={20} className="text-slate-400" />
                 Running Ledger
               </h2>
               <div className="text-xs font-bold text-slate-500 bg-white px-3 py-1.5 rounded-lg border border-slate-200">
                 {ledgerData.length} Transactions
               </div>
             </div>

             <div className="flex-1 overflow-x-auto">
               {!selectedPartyId ? (
                 <div className="h-full flex flex-col items-center justify-center text-slate-400 p-10">
                   <Building2 size={48} className="mb-3 opacity-20" />
                   <p className="font-medium text-sm">Select a {partyType} to view their ledger</p>
                 </div>
               ) : ledgerData.length === 0 ? (
                 <div className="h-full flex flex-col items-center justify-center text-slate-400 p-10">
                   <p className="font-medium text-sm">No transactions found for this party.</p>
                 </div>
               ) : (
                 <table className="w-full text-left border-collapse">
                   <thead>
                     <tr className="bg-slate-50 border-b border-slate-200">
                       <th className="px-5 py-3 text-[10px] font-black text-slate-500 uppercase tracking-wider">Date</th>
                       <th className="px-5 py-3 text-[10px] font-black text-slate-500 uppercase tracking-wider">Details</th>
                       <th className="px-5 py-3 text-[10px] font-black text-slate-500 uppercase tracking-wider text-right">Debit (Due)</th>
                       <th className="px-5 py-3 text-[10px] font-black text-slate-500 uppercase tracking-wider text-right">Credit (Paid)</th>
                       <th className="px-5 py-3 text-[10px] font-black text-slate-500 uppercase tracking-wider text-right">Balance</th>
                     </tr>
                   </thead>
                   <tbody>
                     {ledgerData.map((entry, idx) => (
                       <tr key={entry.id + idx} className="border-b border-slate-100 hover:bg-slate-50/50 transition-colors">
                         <td className="px-5 py-3 text-xs font-bold text-slate-600 whitespace-nowrap">
                           {new Date(entry.date).toLocaleDateString()}
                         </td>
                         <td className="px-5 py-3">
                           <div className="text-sm font-black text-slate-800">{entry.reference}</div>
                           <div className="text-[10px] font-bold text-slate-500 mt-0.5">{entry.remarks}</div>
                         </td>
                         <td className="px-5 py-3 text-right">
                           {entry.type === 'DEBIT' ? (
                             <span className="text-sm font-black text-rose-600 flex items-center justify-end gap-1">
                               {entry.amount.toFixed(2)} <ArrowUpRight size={14}/>
                             </span>
                           ) : '-'}
                         </td>
                         <td className="px-5 py-3 text-right">
                           {entry.type === 'CREDIT' ? (
                             <span className="text-sm font-black text-emerald-600 flex items-center justify-end gap-1">
                               {entry.amount.toFixed(2)} <ArrowDownRight size={14}/>
                             </span>
                           ) : '-'}
                         </td>
                         <td className="px-5 py-3 text-right">
                           <span className={`text-sm font-black ${entry.balance > 0 ? 'text-rose-600' : entry.balance < 0 ? 'text-emerald-600' : 'text-slate-400'}`}>
                             ₹{Math.abs(entry.balance).toFixed(2)} {entry.balance > 0 ? 'Dr' : entry.balance < 0 ? 'Cr' : ''}
                           </span>
                         </td>
                       </tr>
                     ))}
                   </tbody>
                 </table>
               )}
             </div>
           </div>
        </div>
      </div>
    </div>
  );
}
