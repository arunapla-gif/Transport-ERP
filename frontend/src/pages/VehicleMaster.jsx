import React, { useState, useEffect } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { Edit2, Trash2, Save, Search, Truck, User, FileCheck, ShieldAlert, ChevronDown, ChevronUp } from 'lucide-react';

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
    id: null, vehicleNumber: '', type: '6 Wheel (Lorry/Truck)', ladenType: 'Open Body', 
    ownerName: '', ownerPhone: '', ownerPhone2: '', makeModel: '', fitnessExpiry: null, insuranceExpiry: null, npExpiry: null, grossWeight: '', rcStatus: '', rcVerified: false
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
      const cleanNo = formData.vehicleNumber.replace(/\s+/g, '');
      const response = await api.post('/fastag/rc', { vehicleNumber: cleanNo });
      
      const vData = response.data;
      setVahanData(vData);
      
      setFormData(prev => ({
        ...prev,
        type: getVehicleTypeFromWheels(vData.rc_no_of_axle, vData.rc_gvw),
        ownerName: vData.rc_owner_name,
        makeModel: vData.rc_maker_model,
        fitnessExpiry: vData.rc_fit_upto ? new Date(vData.rc_fit_upto) : null,
        insuranceExpiry: vData.rc_insurance_upto ? new Date(vData.rc_insurance_upto) : null,
        npExpiry: vData.rc_np_upto ? new Date(vData.rc_np_upto) : null,
        grossWeight: vData.rc_gvw ? parseInt(vData.rc_gvw) : null,
        rcStatus: vData.rc_status,
        rcVerified: true
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
      const payloadToSave = {
        ...formData,
        grossWeight: formData.grossWeight ? parseInt(formData.grossWeight) : null,
      };

      if (formData.id) {
        await api.put(`/vehicles/${payloadToSave.id}`, payloadToSave);
        toast.success('Vehicle updated successfully');
      } else {
        const { id, ...dataToCreate } = payloadToSave;
        await api.post('/vehicles', dataToCreate);
        toast.success('Vehicle created successfully');
      }
      setFormData({ 
        id: null, vehicleNumber: '', type: '6 Wheel (Lorry/Truck)', ladenType: 'Open Body',
        ownerName: '', ownerPhone: '', ownerPhone2: '', makeModel: '', fitnessExpiry: null, insuranceExpiry: null, npExpiry: null, grossWeight: '', rcStatus: '', rcVerified: false 
      });
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
      type: vehicle.type || '6 Wheel (Lorry/Truck)',
      ladenType: vehicle.ladenType || 'Open Body',
      ownerName: vehicle.ownerName || '',
      ownerPhone: vehicle.ownerPhone || '',
      ownerPhone2: vehicle.ownerPhone2 || '',
      makeModel: vehicle.makeModel || '',
      fitnessExpiry: vehicle.fitnessExpiry ? new Date(vehicle.fitnessExpiry) : null,
      insuranceExpiry: vehicle.insuranceExpiry ? new Date(vehicle.insuranceExpiry) : null,
      npExpiry: vehicle.npExpiry ? new Date(vehicle.npExpiry) : null,
      grossWeight: vehicle.grossWeight || '',
      rcStatus: vehicle.rcStatus || '',
      rcVerified: vehicle.rcVerified || false
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

  const getVehicleTypeFromWheels = (axlesStr, gvwStr) => {
    const axles = parseInt(axlesStr);
    const gvw = parseInt(gvwStr);
    if (!axles) return '6 Wheel (Lorry/Truck)';
    if (axles === 2) return gvw <= 3500 ? '4 Wheel (Van/Minidor)' : '6 Wheel (Lorry/Truck)'; // 6 Wheeler
    if (axles === 3) return '10 Wheel (Taurus)'; // 10 Wheeler
    if (axles === 4) return '12 Wheeler';
    if (axles === 5) return '14 Wheeler';
    if (axles === 6) return '18 Wheeler';
    if (axles === 7) return '22 Wheeler';
    return `${axles * 4 - 6} Wheeler`;
  };

  const filteredVehicles = vehicles.filter(v => 
    (v.vehicleNumber && v.vehicleNumber.toLowerCase().includes(searchTerm.toLowerCase())) || 
    (v.ownerName && v.ownerName.toLowerCase().includes(searchTerm.toLowerCase())) ||
    (v.ownerPhone && v.ownerPhone.toLowerCase().includes(searchTerm.toLowerCase()))
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

      {/* TOP-DOWN STACKED LAYOUT FOR FORMS */}
      <div className="flex flex-col gap-6">
        {/* TOP SECTION: VEHICLE & VAHAN */}
        <div className="space-y-4">
          <GlassCard>
            <div className="flex items-center gap-2 mb-4 border-b border-slate-100 pb-2">
              <Truck size={16} className="text-emerald-600" />
              <h3 className="font-bold text-sm text-slate-800">Vehicle Identity</h3>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-x-6 gap-y-4">
              <div className="flex items-end gap-2">
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
              <DenseSelect label="Vehicle Type" options={['6 Wheel (Lorry/Truck)', '10 Wheel (Taurus)', '12 Wheeler', '14 Wheeler', '18 Wheeler', '22 Wheeler', '4 Wheel (Van/Minidor)']} value={formData.type} onChange={e => setFormData({...formData, type: e.target.value})} />
              <DenseSelect label="Laden Type" options={['Open Body', 'Container']} value={formData.ladenType} onChange={e => setFormData({...formData, ladenType: e.target.value})} />
              
              <div className="md:col-span-3 grid grid-cols-1 md:grid-cols-4 gap-x-6 gap-y-4 pt-2 border-t border-slate-100 mt-2">
                <DenseInput label="Owner Name" value={formData.ownerName} onChange={e => setFormData({...formData, ownerName: e.target.value})} className="md:col-span-2" />
                <DenseInput label="Owner Phone 1" value={formData.ownerPhone} onChange={e => setFormData({...formData, ownerPhone: e.target.value})} />
                <DenseInput label="Owner Phone 2" value={formData.ownerPhone2} onChange={e => setFormData({...formData, ownerPhone2: e.target.value})} />
              </div>
            </div>
        {/* VAHAN RC Auto-fill Results */}
        {vahanData && (
          <div className="mt-5 space-y-3 bg-slate-50/50 p-4 rounded-xl border border-slate-200">
             <div className="flex items-center gap-2 mb-2">
               <span className="text-[10px] font-black tracking-wider text-indigo-600 uppercase bg-indigo-100 px-2 py-0.5 rounded-sm">VAHAN Verified Data</span>
               <span className={`text-[10px] font-black tracking-wider uppercase px-2 py-0.5 rounded-sm ${vahanData.rc_status === 'ACTIVE' ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'}`}>
                 Status: {vahanData.rc_status}
               </span>
             </div>
             
             <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
               {/* Ownership */}
               <div className="p-5 bg-white border border-slate-200 rounded-2xl shadow-sm hover:shadow-md transition-shadow">
                 <h4 className="text-xs font-black text-slate-400 uppercase mb-4 border-b border-slate-100 pb-2 flex items-center gap-2"><User size={14} className="text-indigo-500"/> Ownership Details</h4>
                 <div className="space-y-3">
                   <div className="flex justify-between items-center"><span className="text-sm text-slate-500">Registered Owner</span> <span className="text-sm font-bold text-slate-800 text-right">{vahanData.rc_owner_name}</span></div>
                   <div className="flex justify-between items-center"><span className="text-sm text-slate-500">Registration Date</span> <span className="text-sm font-bold text-slate-800 text-right">{vahanData.rc_regn_dt}</span></div>
                   <div className="flex justify-between items-center"><span className="text-sm text-slate-500">RTO Office</span> <span className="text-sm font-bold text-slate-800 text-right">{vahanData.rc_registered_at}</span></div>
                   <div className="flex justify-between items-center"><span className="text-sm text-slate-500">Owner Type</span> <span className="text-sm font-bold text-slate-800 text-right">{vahanData.rc_owner_cd_desc}</span></div>
                 </div>
               </div>

               {/* Specs & Payload */}
               <div className="p-5 bg-white border border-slate-200 rounded-2xl shadow-sm hover:shadow-md transition-shadow">
                 <h4 className="text-xs font-black text-slate-400 uppercase mb-4 border-b border-slate-100 pb-2 flex items-center gap-2"><Truck size={14} className="text-amber-500"/> Vehicle & Payload Specs</h4>
                 
                 <div className="flex items-center gap-4 mb-4 p-4 bg-gradient-to-r from-amber-50 to-orange-50 rounded-xl border border-amber-100/50">
                   <div className="flex-1">
                     <div className="text-[10px] text-amber-600 font-black uppercase tracking-wider mb-0.5">Max Legal Payload</div>
                     <div className="text-3xl font-black text-amber-900 tracking-tight">{vahanData.rc_gvw && vahanData.rc_unld_wt ? parseInt(vahanData.rc_gvw) - parseInt(vahanData.rc_unld_wt) : 'N/A'} <span className="text-sm font-bold text-amber-700">KG</span></div>
                   </div>
                   <div className="h-10 w-[1px] bg-amber-200/60"></div>
                   <div className="flex-1 text-right space-y-1">
                     <div className="text-[11px] text-amber-700/80 uppercase font-black tracking-wide">Gross: {vahanData.rc_gvw || '-'} KG</div>
                     <div className="text-[11px] text-amber-700/80 uppercase font-black tracking-wide">Unladen: {vahanData.rc_unld_wt || '-'} KG</div>
                   </div>
                 </div>

                 <div className="space-y-3">
                   <div className="flex justify-between items-center"><span className="text-sm text-slate-500">Make & Model</span> <span className="text-sm font-bold text-slate-800 text-right truncate max-w-[180px]" title={`${vahanData.rc_maker_desc} ${vahanData.rc_maker_model}`}>{vahanData.rc_maker_desc} {vahanData.rc_maker_model}</span></div>
                   <div className="flex justify-between items-center"><span className="text-sm text-slate-500">Vehicle Class</span> <span className="text-sm font-bold text-slate-800 text-right truncate max-w-[180px]">{vahanData.rc_vh_class_desc}</span></div>
                   <div className="flex justify-between items-center"><span className="text-sm text-slate-500">Wheels & Axles</span> <span className="text-sm font-bold text-slate-800 text-right"><span className="text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded border border-indigo-100 mr-1.5 font-black uppercase text-[10px] tracking-wider">{getVehicleTypeFromWheels(vahanData.rc_no_of_axle, vahanData.rc_gvw)}</span> ({vahanData.rc_no_of_axle || '?'} Axles)</span></div>
                 </div>
               </div>

               {/* Compliance */}
               <div className="p-5 bg-white border border-slate-200 rounded-2xl shadow-sm hover:shadow-md transition-shadow">
                 <h4 className="text-xs font-black text-slate-400 uppercase mb-4 border-b border-slate-100 pb-2 flex items-center gap-2"><FileCheck size={14} className="text-emerald-500"/> Compliance & Tax</h4>
                 <div className="grid grid-cols-2 gap-3">
                   <div className="p-3 rounded-xl bg-slate-50/80 border border-slate-100">
                     <div className="text-[10px] uppercase font-black text-slate-400 mb-0.5 tracking-wider">Fitness Expiry</div>
                     <div className="text-sm font-black text-emerald-700">{vahanData.rc_fit_upto || '-'}</div>
                   </div>
                   <div className="p-3 rounded-xl bg-slate-50/80 border border-slate-100">
                     <div className="text-[10px] uppercase font-black text-slate-400 mb-0.5 tracking-wider">Insurance Expiry</div>
                     <div className="text-sm font-black text-emerald-700">{vahanData.rc_insurance_upto || '-'}</div>
                   </div>
                   <div className="p-3 rounded-xl bg-slate-50/80 border border-slate-100">
                     <div className="text-[10px] uppercase font-black text-slate-400 mb-0.5 tracking-wider">PUC Expiry</div>
                     <div className="text-sm font-black text-emerald-700">{vahanData.rc_pucc_upto || '-'}</div>
                   </div>
                   <div className="p-3 rounded-xl bg-slate-50/80 border border-slate-100">
                     <div className="text-[10px] uppercase font-black text-slate-400 mb-0.5 tracking-wider">Tax Expiry</div>
                     <div className="text-sm font-black text-emerald-700">{vahanData.rc_tax_upto || '-'}</div>
                   </div>
                 </div>
               </div>

               {/* Permits & Legal */}
               <div className="p-5 bg-white border border-slate-200 rounded-2xl shadow-sm hover:shadow-md transition-shadow">
                 <h4 className="text-xs font-black text-slate-400 uppercase mb-4 border-b border-slate-100 pb-2 flex items-center gap-2"><ShieldAlert size={14} className="text-rose-500"/> Permit & Finance</h4>
                 <div className="space-y-4">
                   <div className="flex justify-between items-center"><span className="text-sm text-slate-500">Permit Number</span> <span className="text-sm font-bold text-slate-800 text-right truncate max-w-[150px]" title={vahanData.rc_permit_no}>{vahanData.rc_permit_no || '-'}</span></div>
                   <div className="flex justify-between items-center"><span className="text-sm text-slate-500">Base Permit Expiry</span> <span className="text-sm font-bold text-slate-800 text-right">{vahanData.rc_permit_valid_upto || '-'}</span></div>
                   <div className="flex justify-between items-center">
                     <span className="text-sm text-slate-500 flex items-center gap-1">Nat. Permit Expiry</span> 
                     {vahanData.rc_np_upto ? (
                       <span className="text-sm font-bold text-slate-800 text-right">{vahanData.rc_np_upto}</span>
                     ) : (
                       <span className="px-2 py-0.5 rounded border border-rose-200 text-[10px] font-black uppercase tracking-wider bg-rose-100 text-rose-700 shadow-sm animate-pulse">
                         Missing (Local Only)
                       </span>
                     )}
                   </div>
                   <div className="flex justify-between items-center"><span className="text-sm text-slate-500">Financer Bank</span> <span className="text-sm font-bold text-slate-800 text-right truncate max-w-[150px]">{vahanData.rc_financer || 'None'}</span></div>
                   <div className="flex justify-between items-center pt-1">
                     <span className="text-sm text-slate-500">Blacklist Status</span> 
                     <span className={`px-2.5 py-1 rounded-md text-xs font-black uppercase tracking-wider ${vahanData.rc_blacklist_status ? 'bg-rose-100 text-rose-700' : 'bg-emerald-100 text-emerald-700'}`}>
                       {vahanData.rc_blacklist_status || 'CLEAR'}
                     </span>
                   </div>
                 </div>
               </div>
             </div>
          </div>
        )}

          </GlassCard>
        </div>

        {/* ACTION BUTTONS */}
        <GlassCard>
            <div className="flex items-center justify-end gap-3 py-2">
              <button onClick={() => {
                setFormData({ id: null, vehicleNumber: '', type: '6 Wheel (Lorry/Truck)', ladenType: 'Open Body', ownerName: '', ownerPhone: '', ownerPhone2: '', makeModel: '', fitnessExpiry: null, insuranceExpiry: null, npExpiry: null, grossWeight: '', rcStatus: '', rcVerified: false });
                setVahanData(null);
              }} className="h-10 px-6 bg-white border border-slate-200 text-slate-600 rounded-lg font-bold text-xs hover:bg-slate-50 shadow-sm transition-all">
                Clear Form
              </button>
              <button onClick={handleSave} disabled={loading} className="h-10 px-8 bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white rounded-lg font-bold text-sm shadow-md hover:shadow-lg hover:-translate-y-[1px] active:scale-[0.98] transition-all flex items-center gap-2">
                <Save size={16} className={loading ? 'animate-pulse' : ''} /> {formData.id ? 'Update Record' : 'Save Vehicle Record'}
              </button>
            </div>
        </GlassCard>
      </div>

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
                <th className="px-4 py-3 font-bold uppercase tracking-wider">Owner</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredVehicles.length > 0 ? filteredVehicles.map((v) => (
                <tr key={v.id} className="hover:bg-slate-50/50 transition-colors group">
                  <td className="px-4 py-3 font-bold text-emerald-700">
                    <div className="flex items-center gap-2">
                       {v.vehicleNumber}
                       {v.rcVerified && <span title="VAHAN Verified" className="bg-blue-100 text-blue-700 text-[8px] px-1.5 py-0.5 rounded-sm uppercase tracking-wider font-black">Verified</span>}
                    </div>
                  </td>
                  <td className="px-4 py-3 text-slate-600">
                    <div>{v.type || '-'}</div>
                    <div className="text-[10px] uppercase font-bold text-slate-400 mt-0.5">{v.ladenType || 'Open Body'}</div>
                  </td>
                  <td className="px-4 py-3 text-slate-600">
                    <div className="text-xs truncate max-w-[150px]" title={v.ownerName}>{v.ownerName || '-'}</div>
                    {v.ownerPhone && <div className="text-[10px] text-slate-400 mt-0.5">Ph1: {v.ownerPhone}</div>}
                    {v.ownerPhone2 && <div className="text-[10px] text-slate-400 mt-0.5">Ph2: {v.ownerPhone2}</div>}
                  </td>
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
