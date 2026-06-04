import React, { useState, useEffect } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { Edit2, Trash2, Save, Search, Truck } from 'lucide-react';

// Premium Dense Primitives
const DenseInput = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-emerald-600">{label}</label>}
    <input 
      className="w-full h-9 px-2.5 border border-slate-200 rounded-lg bg-white/50 text-sm font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 hover:border-slate-300 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" 
      {...props} 
    />
  </div>
);

const DenseSelect = ({ label, options, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-emerald-600">{label}</label>}
    <select 
      className="w-full h-9 px-2.5 border border-slate-200 rounded-lg bg-white/50 text-sm font-medium text-slate-800 focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 hover:border-slate-300 transition-all appearance-none cursor-pointer shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" 
      {...props}
    >
      {options.map((opt, i) => (
        <option key={i} value={opt.value !== undefined ? opt.value : opt}>{opt.label || opt}</option>
      ))}
    </select>
  </div>
);

const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/80 backdrop-blur-2xl border border-white/60 rounded-xl p-4 shadow-[0_4px_20px_rgb(16,185,129,0.04)] relative overflow-hidden transition-all duration-300 hover:shadow-[0_4px_20px_rgb(16,185,129,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

export default function VehicleMaster() {
  const [vehicles, setVehicles] = useState([]);
  const [formData, setFormData] = useState({
    id: null, vehicleNumber: '', type: 'Lorry', driverName: '', license: '', phone: ''
  });
  const [loading, setLoading] = useState(false);
  const [vahanData, setVahanData] = useState(null);
  const [fetchingRc, setFetchingRc] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');

  useKeyboardFlow({
    onSave: (e) => handleSave(e || { preventDefault: () => {} })
  });

  useEffect(() => {
    fetchVehicles();
  }, []);

  const fetchVehicles = async () => {
    try {
      const data = await api.get('/vehicles');
      setVehicles(data || []);
    } catch (err) {
      toast.error('Failed to fetch data.');
    }
  };

  const handleFetchRC = async () => {
    if (!formData.vehicleNumber) {
      toast.error('Please enter a vehicle number first');
      return;
    }
    setFetchingRc(true);
    setVahanData(null);
    try {
      // Clean vehicle number (remove spaces)
      const cleanNo = formData.vehicleNumber.replace(/\s+/g, '');
      const response = await api.get(`/vahan/rc/${cleanNo}`);
      
      setVahanData(response);
      
      // Auto-fill some fields based on VAHAN if they are empty
      setFormData(prev => ({
        ...prev,
        type: response.vehicleClass.includes('HGV') ? 'Lorry' : prev.type,
      }));
      toast.success('RC Details fetched successfully from VAHAN');
    } catch (err) {
      toast.error('Failed to fetch RC details from VAHAN');
    } finally {
      setFetchingRc(false);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!formData.vehicleNumber) return toast.error("Vehicle Number is required");
    
    setLoading(true);
    try {
      if (formData.id) {
        await api.put(`/vehicles/${formData.id}`, formData);
        toast.success('Vehicle updated successfully');
      } else {
        const { id, ...dataToCreate } = formData;
        await api.post('/vehicles', dataToCreate);
        toast.success('Vehicle created successfully');
      }
      setFormData({ id: null, vehicleNumber: '', type: 'Lorry', driverName: '', license: '', phone: '' });
      fetchVehicles();
    } catch (err) {
      toast.error('Failed to save record: ' + (err.error || err.message || 'Unknown error'));
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (vehicle) => {
    setFormData({
      id: vehicle.id,
      vehicleNumber: vehicle.vehicleNumber || '',
      type: vehicle.type || 'Lorry',
      driverName: vehicle.driverName || '',
      license: vehicle.license || '',
      phone: vehicle.phone || ''
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this record?')) return;
    try {
      await api.delete(`/vehicles/${id}`);
      fetchVehicles();
      toast.success('Record deleted');
    } catch (err) {
      toast.error('Failed to delete record');
    }
  };

  const filteredVehicles = vehicles.filter(v => 
    (v.vehicleNumber && v.vehicleNumber.toLowerCase().includes(searchTerm.toLowerCase())) || 
    (v.driverName && v.driverName.toLowerCase().includes(searchTerm.toLowerCase())) ||
    (v.phone && v.phone.toLowerCase().includes(searchTerm.toLowerCase()))
  );

  return (
    <div className="space-y-4 max-w-[1200px] mx-auto pb-10" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* HEADER CARD */}
      <GlassCard className="!p-4">
        <div className="flex items-center gap-3">
          <div className="bg-emerald-50 text-emerald-600 p-2 rounded-xl shadow-inner border border-emerald-100/50">
            <Truck size={20} />
          </div>
          <div>
            <h2 className="font-bold text-lg text-slate-800 tracking-tight">Vehicle Master</h2>
            <p className="text-xs font-medium text-slate-500">Manage lorries, vehicle types, and driver details.</p>
          </div>
        </div>
      </GlassCard>

      {/* FORM CARD */}
      <GlassCard>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-x-6 gap-y-4">
          <div className="lg:col-span-2 flex items-end gap-2">
            <DenseInput 
              label="Vehicle Number *" 
              value={formData.vehicleNumber} 
              onChange={e => setFormData({...formData, vehicleNumber: e.target.value})} 
              className="flex-1 [&>input]:font-bold [&>input]:text-emerald-900 [&>input]:uppercase" 
            />
            <button 
              onClick={handleFetchRC} 
              disabled={fetchingRc || !formData.vehicleNumber}
              className="h-9 px-4 bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white rounded-lg font-bold text-xs shadow-sm hover:shadow active:scale-[0.98] transition-all whitespace-nowrap"
            >
              {fetchingRc ? 'Fetching...' : 'Verify RC'}
            </button>
          </div>
          <DenseSelect label="Vehicle Type" options={['Lorry', 'Minidor', 'Van', 'Truck']} value={formData.type} onChange={e => setFormData({...formData, type: e.target.value})} className="lg:col-span-2" />
          
          <DenseInput label="Driver Name" value={formData.driverName} onChange={e => setFormData({...formData, driverName: e.target.value})} className="lg:col-span-2" />
          <DenseInput label="Driver License No" value={formData.license} onChange={e => setFormData({...formData, license: e.target.value})} className="[&>input]:uppercase" />
          <DenseInput label="Driver Phone" value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} />
        </div>

        {/* VAHAN RC Auto-fill Results */}
        {vahanData && (
          <div className="mt-5 p-3 rounded-xl border border-indigo-100 bg-gradient-to-r from-indigo-50/50 to-blue-50/50">
            <div className="flex items-center gap-2 mb-2">
              <span className="text-[10px] font-black tracking-wider text-indigo-600 uppercase bg-indigo-100 px-2 py-0.5 rounded-sm">VAHAN Verified</span>
              <span className={`text-[10px] font-black tracking-wider uppercase px-2 py-0.5 rounded-sm ${vahanData.rcStatus === 'ACTIVE' ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'}`}>
                RC: {vahanData.rcStatus}
              </span>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <p className="text-[10px] uppercase font-bold text-slate-400">Registered Owner</p>
                <p className="text-xs font-bold text-slate-800">{vahanData.ownerName}</p>
              </div>
              <div>
                <p className="text-[10px] uppercase font-bold text-slate-400">Maker / Model</p>
                <p className="text-xs font-bold text-slate-800">{vahanData.makerModel}</p>
              </div>
              <div className="flex gap-4">
                <div>
                  <p className="text-[10px] uppercase font-bold text-slate-400">Fitness</p>
                  <p className="text-xs font-bold text-emerald-700">{vahanData.fitnessUpto}</p>
                </div>
                <div>
                  <p className="text-[10px] uppercase font-bold text-slate-400">Insurance</p>
                  <p className="text-xs font-bold text-emerald-700">{vahanData.insuranceUpto}</p>
                </div>
              </div>
            </div>
          </div>
        )}

        <div className="flex justify-end gap-3 mt-6 pt-4 border-t border-slate-100">
          <button onClick={() => setFormData({ id: null, vehicleNumber: '', type: 'Lorry', driverName: '', license: '', phone: '' })} className="h-9 px-4 bg-white border border-slate-200 text-slate-600 rounded-lg font-bold text-xs hover:bg-slate-50 shadow-sm hover:-translate-y-[1px] active:scale-[0.98] transition-all">
            Clear
          </button>
          <button onClick={handleSave} disabled={loading} className="h-9 px-5 bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white rounded-lg font-bold text-xs shadow-md hover:shadow-lg hover:-translate-y-[1px] active:scale-[0.98] transition-all flex items-center gap-1.5">
            <Save size={14} className={loading ? 'animate-pulse' : ''} /> {formData.id ? 'Update Vehicle' : 'Save Vehicle'}
          </button>
        </div>
      </GlassCard>

      {/* LIST CARD */}
      <GlassCard className="!p-0">
        <div className="p-4 border-b border-slate-100 flex justify-between items-center bg-slate-50/50">
          <h3 className="font-bold text-sm text-slate-800">Saved Vehicles <span className="text-slate-400 font-medium ml-1">({vehicles.length})</span></h3>
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input 
              type="text" 
              placeholder="Search lorry or driver..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="h-8 pl-9 pr-3 w-64 border border-slate-200 rounded-lg bg-white text-xs focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
            />
          </div>
        </div>
        <div className="overflow-x-auto max-h-[400px] overflow-y-auto custom-scrollbar">
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-slate-500 bg-slate-50/80 sticky top-0 backdrop-blur-md z-10 border-b border-slate-200">
              <tr>
                <th className="px-4 py-3 font-bold uppercase tracking-wider">Vehicle No</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider">Type</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider">Driver Name</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider">Phone</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredVehicles.length > 0 ? filteredVehicles.map((v) => (
                <tr key={v.id} className="hover:bg-slate-50/50 transition-colors group">
                  <td className="px-4 py-3 font-bold text-emerald-700">{v.vehicleNumber}</td>
                  <td className="px-4 py-3 text-slate-600">{v.type || '-'}</td>
                  <td className="px-4 py-3 text-slate-800 font-medium">{v.driverName || '-'}</td>
                  <td className="px-4 py-3 text-slate-600">{v.phone || '-'}</td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                      <button onClick={() => handleEdit(v)} className="p-1.5 text-blue-600 hover:bg-blue-50 rounded-md transition-colors"><Edit2 size={14} /></button>
                      <button onClick={() => handleDelete(v.id)} className="p-1.5 text-rose-600 hover:bg-rose-50 rounded-md transition-colors"><Trash2 size={14} /></button>
                    </div>
                  </td>
                </tr>
              )) : (
                <tr>
                  <td colSpan="5" className="px-4 py-8 text-center text-slate-500 text-sm">No records found.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </GlassCard>
    </div>
  );
}
