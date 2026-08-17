import React from 'react';
import { GlassCard, DenseInput } from '../ui/DensePrimitives';
import { AsyncSearchableSelect } from '../ui/AsyncSearchableSelect';
import { PackageCheck } from 'lucide-react';

export const GdmDocumentDetails = React.memo(({
  gdmNumberDisplay,
  gdmDetails,
  setGdmDetails,
  consigneeMode,
  setConsigneeMode,
  selectedConsigneeData,
  setSelectedConsigneeData,
  fetchConsigneesAsync,
  handleConsigneeChange
}) => {
  return (
    <GlassCard className="relative z-20 h-full flex flex-col">
      <div className="flex items-center justify-between mb-4 border-b border-slate-100 pb-2">
        <div className="flex items-center gap-2">
          <div className="bg-indigo-50 text-indigo-600 p-2 rounded-lg shadow-inner border border-indigo-100/50"><PackageCheck size={18} /></div>
          <h3 className="font-bold text-lg text-slate-800 tracking-tight">Delivery Memo</h3>
        </div>
      </div>
      
      <div className="space-y-3">
        <div className="flex gap-2">
          <DenseInput label="GDM No" value={gdmNumberDisplay} readOnly className="w-1/3 [&>input]:font-black [&>input]:text-indigo-900 [&>input]:bg-indigo-50/50" />
          <DenseInput label="Date" type="date" value={gdmDetails.date} onChange={e => setGdmDetails(prev => ({...prev, date: e.target.value}))} className="w-1/3" />
          <DenseInput label="Time" type="time" value={gdmDetails.time || ''} onChange={e => setGdmDetails(prev => ({...prev, time: e.target.value}))} className="w-1/3" />
        </div>
        <div className="flex gap-2">
          <DenseInput label="From" value={gdmDetails.fromLocation} onChange={e => setGdmDetails(prev => ({...prev, fromLocation: e.target.value}))} className="w-1/3" />
          <DenseInput label="To (Name)" value={gdmDetails.toName} onChange={e => setGdmDetails(prev => ({...prev, toName: e.target.value}))} className="w-1/3" />
          <DenseInput label="Delivery At" value={gdmDetails.deliveryAt} onChange={e => setGdmDetails(prev => ({...prev, deliveryAt: e.target.value}))} className="w-1/3 [&>input]:border-amber-300 [&>input]:bg-amber-50 focus-within:[&>input]:border-amber-500" />
        </div>
        <div className="p-3 bg-slate-50/50 rounded-xl border border-slate-200 shadow-inner mt-2 relative z-20">
          <div className="flex flex-col gap-2">
            <div className="flex flex-col">
              <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Consignee Mode</label>
              <select 
                className="h-9 px-3 bg-white border border-slate-200 text-sm font-semibold rounded-lg focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500 text-slate-700"
                value={consigneeMode} 
                onChange={e => {
                  const newMode = e.target.value;
                  setConsigneeMode(newMode);
                  if (newMode === 'Multiple Consignee') {
                    setGdmDetails(prev => ({...prev, toName: 'AS PER BILLS', deliveryAt: ''}));
                    setSelectedConsigneeData(null);
                  } else {
                    setGdmDetails(prev => ({...prev, toName: '', deliveryAt: ''}));
                  }
                }}
              >
                <option>Multiple Consignee</option>
                <option>Single Consignee</option>
              </select>
            </div>
            {consigneeMode === 'Single Consignee' && (
              <div className="mt-1">
                <AsyncSearchableSelect 
                  id="consignee-select"
                  nextFocusId="gdm-gc-search"
                  label="Select Consignee"
                  fetchOptions={fetchConsigneesAsync}
                  value={selectedConsigneeData?.id?.toString() || ''}
                  onChange={handleConsigneeChange}
                  placeholder="Search consignee..."
                  className="[&>div>button]:h-9 [&>div>button]:bg-white [&>div>button]:border-slate-200"
                />
              </div>
            )}
            <p className="text-[9px] text-slate-400 font-medium leading-tight">
              {consigneeMode === 'Multiple Consignee' 
                ? "Each GC can have a different consignee." 
                : "All GCs in this GDM are for one consignee."}
            </p>
          </div>
        </div>
      </div>
    </GlassCard>
  );
});
