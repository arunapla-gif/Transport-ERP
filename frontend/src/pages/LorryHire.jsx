import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { Truck, Save, CheckCircle, IndianRupee } from 'lucide-react';
import { SearchableSelect } from '../components/ui/SearchableSelect';

export default function LorryHire() {
  const [vehicles, setVehicles] = useState([]);
  const [selectedVehicleId, setSelectedVehicleId] = useState('');
  
  const [hireData, setHireData] = useState({
    tripNumber: 'TRIP-' + Math.floor(1000 + Math.random() * 9000),
    lorryHire: '',
    advancePaid: '',
    sourcedBy: 'Direct',
    brokerName: '',
    loadingPayer: 'Transport',
    loadingCharge: '',
    commissionAmount: '',
    commissionDetails: '',
    remarks: ''
  });

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    fetchVehicles();
  }, []);

  const fetchVehicles = async () => {
    try {
      const vehRes = await api.get('/vehicles');
      setVehicles(Array.isArray(vehRes) ? vehRes : []);
    } catch (err) {
      setError('Failed to load vehicles');
    }
  };

  const vehicleOptions = vehicles.map(v => ({ value: v.id, label: v.vehicleNumber }));

  const handleSaveHire = async () => {
    if (!selectedVehicleId) return setError('Please select a vehicle');
    if (!hireData.lorryHire) return setError('Please enter the negotiated lorry hire');

    try {
      setLoading(true);
      setError('');
      
      const payload = {
        tripNumber: hireData.tripNumber,
        vehicleId: parseInt(selectedVehicleId),
        lorryHire: parseFloat(hireData.lorryHire) || 0,
        advancePaid: parseFloat(hireData.advancePaid) || 0,
        balanceAmount: (parseFloat(hireData.lorryHire) || 0) - (parseFloat(hireData.advancePaid) || 0),
        sourcedBy: hireData.sourcedBy,
        brokerName: hireData.brokerName,
        loadingPayer: hireData.loadingPayer,
        loadingCharge: parseFloat(hireData.loadingCharge) || 0,
        commissionAmount: parseFloat(hireData.commissionAmount) || 0,
        commissionDetails: hireData.commissionDetails,
        remarks: hireData.remarks,
        gdmIds: [] // GDMs will be attached in the Trip Settlement page
      };

      await api.post('/trips', payload);
      setSuccess(`Lorry Hire Agreement for ${hireData.tripNumber} saved successfully!`);
      
      // Reset form
      setHireData({
        tripNumber: 'TRIP-' + Math.floor(1000 + Math.random() * 9000),
        lorryHire: '',
        advancePaid: '',
        sourcedBy: 'Direct',
        brokerName: '',
        loadingPayer: 'Transport',
        loadingCharge: '',
        commissionAmount: '',
        commissionDetails: '',
        remarks: ''
      });
      setSelectedVehicleId('');

      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError(err.message || 'Failed to save Lorry Hire');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6 pb-10 pt-4" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      <div className="flex items-center gap-3 mb-8">
        <div className="bg-amber-100 text-amber-700 p-2.5 rounded-xl shadow-sm">
          <IndianRupee size={24} />
        </div>
        <div>
          <h1 className="text-2xl font-black text-slate-800 tracking-tight">Lorry Hire Agreement</h1>
          <p className="text-sm font-medium text-slate-500">Negotiate and record Lorry Hire and Advance payments before the trip.</p>
        </div>
      </div>

      {error && <div className="bg-rose-50 text-rose-600 p-4 rounded-xl text-sm font-bold border border-rose-200">{error}</div>}
      {success && <div className="bg-emerald-50 text-emerald-600 p-4 rounded-xl text-sm font-bold border border-emerald-200 flex items-center gap-2"><CheckCircle size={16}/> {success}</div>}

      <div className="bg-white/80 backdrop-blur-xl border border-slate-200/60 rounded-2xl p-6 shadow-sm">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          {/* Left: Vehicle Selection */}
          <div className="space-y-5">
             <h2 className="text-lg font-black text-slate-800 flex items-center gap-2 border-b border-slate-100 pb-3">
               <span className="w-6 h-6 rounded-md bg-slate-100 text-slate-600 flex items-center justify-center text-xs">1</span> 
               Vehicle Details
             </h2>
             
             <SearchableSelect 
               label="Select Vehicle"
               options={vehicleOptions}
               value={selectedVehicleId}
               onChange={(val) => setSelectedVehicleId(val)}
               placeholder="Search vehicle..."
             />
             
             <div>
               <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-1 block">Trip Reference Number</label>
               <input 
                 type="text" 
                 value={hireData.tripNumber} 
                 readOnly
                 className="w-full h-11 px-3 bg-slate-100 border border-slate-200 rounded-lg text-sm font-bold text-slate-700 focus:outline-none" 
               />
             </div>

             <div>
               <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-1 block">Vehicle Source</label>
               <select 
                 value={hireData.sourcedBy}
                 onChange={e => setHireData({...hireData, sourcedBy: e.target.value})}
                 className="w-full h-11 px-3 bg-white border border-slate-200 rounded-lg text-sm font-bold text-slate-700 focus:outline-none focus:border-amber-500"
               >
                 <option value="Direct">Direct</option>
                 <option value="Broker">Broker / Third Party</option>
               </select>
             </div>

             {hireData.sourcedBy === 'Broker' && (
               <div>
                 <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-1 block">Broker Name</label>
                 <input 
                   type="text" 
                   value={hireData.brokerName} 
                   onChange={e => setHireData({...hireData, brokerName: e.target.value})}
                   placeholder="Enter Broker Name"
                   className="w-full h-11 px-3 bg-white border border-slate-200 rounded-lg text-sm font-bold text-slate-700 focus:outline-none focus:border-amber-500" 
                 />
               </div>
             )}

             <div className="grid grid-cols-2 gap-4">
               <div>
                 <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-1 block">Loading Payer</label>
                 <select 
                   value={hireData.loadingPayer}
                   onChange={e => setHireData({...hireData, loadingPayer: e.target.value})}
                   className="w-full h-11 px-3 bg-white border border-slate-200 rounded-lg text-sm font-bold text-slate-700 focus:outline-none focus:border-amber-500"
                 >
                   <option value="Transport">Transport (Us)</option>
                   <option value="Lorry Owner">Lorry Owner</option>
                   <option value="Consignor">Consignor</option>
                 </select>
               </div>
               <div>
                 <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-1 block">Loading Charge</label>
                 <input 
                   type="number" 
                   value={hireData.loadingCharge} 
                   onChange={e => setHireData({...hireData, loadingCharge: e.target.value})}
                   placeholder="0.00"
                   className="w-full h-11 px-3 bg-white border border-slate-200 rounded-lg text-sm font-bold text-slate-700 focus:outline-none focus:border-amber-500" 
                 />
               </div>
             </div>

             <div>
               <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-1 block">Remarks / Terms</label>
               <textarea 
                 value={hireData.remarks}
                 onChange={e => setHireData({...hireData, remarks: e.target.value})}
                 placeholder="e.g., Driver requested advance via cash..."
                 className="w-full p-3 bg-white border border-slate-200 rounded-lg text-sm font-medium text-slate-700 focus:border-amber-500 focus:ring-2 focus:ring-amber-500/20 resize-none h-24"
               />
             </div>
          </div>

          {/* Right: Financials */}
          <div className="space-y-5 bg-amber-50/50 p-5 rounded-xl border border-amber-100/50">
             <h2 className="text-lg font-black text-amber-900 flex items-center gap-2 border-b border-amber-200/50 pb-3">
               <span className="w-6 h-6 rounded-md bg-amber-100 text-amber-700 flex items-center justify-center text-xs">2</span> 
               Negotiated Hire
             </h2>
             
             <div>
               <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-1 block">Total Lorry Hire</label>
               <div className="relative">
                 <span className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 font-bold">₹</span>
                 <input 
                   type="number" 
                   value={hireData.lorryHire} 
                   onChange={e => setHireData({...hireData, lorryHire: e.target.value})}
                   placeholder="0.00"
                   className="w-full h-12 pl-8 pr-3 bg-white border border-slate-200 rounded-lg text-xl font-black text-slate-800 focus:border-amber-500 focus:ring-2 focus:ring-amber-500/20" 
                 />
               </div>
             </div>
             
             <div>
               <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-1 block">Advance Paid Now</label>
               <div className="relative">
                 <span className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 font-bold">₹</span>
                 <input 
                   type="number" 
                   value={hireData.advancePaid} 
                   onChange={e => setHireData({...hireData, advancePaid: e.target.value})}
                   placeholder="0.00"
                   className="w-full h-12 pl-8 pr-3 bg-white border border-slate-200 rounded-lg text-xl font-black text-emerald-600 focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20" 
                 />
               </div>
             </div>
             
             <div className="pt-4 border-t border-amber-200/50 flex justify-between items-center mt-6 mb-4">
               <span className="text-sm font-bold text-slate-600">Balance Lorry Hire:</span>
               <span className="text-2xl font-black text-slate-800">
                 ₹ {((parseFloat(hireData.lorryHire) || 0) - (parseFloat(hireData.advancePaid) || 0)).toFixed(2)}
               </span>
             </div>

             {/* Commission Details block */}
             <div className="bg-white/50 rounded-xl p-4 border border-amber-200/50 mt-4 space-y-4">
               <h3 className="text-sm font-bold text-amber-900 border-b border-amber-200/50 pb-2">Commissions & Extras</h3>
               <div className="grid grid-cols-2 gap-4">
                 <div className="col-span-2">
                   <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 block">Commission Details / Type</label>
                   <input 
                     type="text" 
                     value={hireData.commissionDetails} 
                     onChange={e => setHireData({...hireData, commissionDetails: e.target.value})}
                     placeholder="e.g. Brokerage, Mamool..."
                     className="w-full h-10 px-3 bg-white border border-amber-200 rounded-lg text-sm font-bold text-slate-700 focus:border-amber-500 focus:outline-none" 
                   />
                 </div>
                 <div className="col-span-2">
                   <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 block">Commission Amount</label>
                   <div className="relative">
                     <span className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 font-bold">₹</span>
                     <input 
                       type="number" 
                       value={hireData.commissionAmount} 
                       onChange={e => setHireData({...hireData, commissionAmount: e.target.value})}
                       placeholder="0.00"
                       className="w-full h-10 pl-8 pr-3 bg-white border border-amber-200 rounded-lg text-sm font-black text-slate-700 focus:border-amber-500 focus:outline-none" 
                     />
                   </div>
                 </div>
               </div>
             </div>
          </div>
        </div>

        <div className="mt-8 pt-6 border-t border-slate-100 flex justify-end">
          <button 
            onClick={handleSaveHire} 
            disabled={loading}
            className="px-8 h-12 bg-amber-600 hover:bg-amber-500 disabled:bg-slate-300 text-white rounded-xl font-black shadow-[0_4px_15px_rgba(217,119,6,0.3)] transition-all flex items-center justify-center gap-2"
          >
            <Save size={18} /> {loading ? 'Saving...' : 'Lock Lorry Hire'}
          </button>
        </div>
      </div>
    </div>
  );
}
