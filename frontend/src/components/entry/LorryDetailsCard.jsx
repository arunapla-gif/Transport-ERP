import React from 'react';
import { GlassCard, DenseInput } from '../ui/DensePrimitives';
import { Button } from '../ui/Button';
import { SearchableSelect } from '../ui/SearchableSelect';
import { Truck, ShieldAlert } from 'lucide-react';

export const LorryDetailsCard = React.memo(({ 
  gdmDetails,
  lorryDetails,
  setLorryDetails,
  vehicleOptions,
  handleVehicleChange,
  dlDetails,
  setDlDetails,
  fetchingDl,
  handleFetchDL,
  dlData
}) => {
  return (
    <GlassCard className="h-full flex flex-col">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="bg-emerald-50 text-emerald-600 p-2 rounded-lg shadow-inner border border-emerald-100/50"><Truck size={18} /></div>
          <h3 className="font-bold text-lg text-slate-800 tracking-tight">Lorry Details</h3>
        </div>
        
        <div className="flex items-center gap-2">
          {gdmDetails.cewbNumber && (
            <div className="px-2.5 py-1 bg-amber-100 text-amber-800 text-[11px] font-black tracking-wider uppercase rounded-md border border-amber-300 shadow-sm">
              CEWB: {gdmDetails.cewbNumber}
            </div>
          )}
        </div>
      </div>

      <div className="flex-1 flex flex-col gap-4 justify-between">
        <SearchableSelect 
          id="vehicle-select"
          nextFocusId="gdm-gc-search"
          label="Search Lorry *"
          options={vehicleOptions}
          value={lorryDetails.vehicleId?.toString()}
          onChange={handleVehicleChange}
          placeholder=""
          className="[&>div>button]:h-10 [&>div>button]:bg-slate-50/50 [&>div>button]:border-slate-200"
        />
        
        <div className="space-y-4 pt-1 mt-1 flex-1 flex flex-col justify-between">
           <div className="flex flex-col gap-3 p-4 bg-slate-50/50 rounded-xl border border-slate-200 shadow-inner">
             <div className="flex items-center gap-2 mb-1">
               <ShieldAlert size={16} className="text-blue-500" />
               <span className="text-[11px] font-bold uppercase tracking-wider text-slate-500">License Verification</span>
             </div>
             <div className="flex items-end gap-3">
               <DenseInput label="DL No." value={dlDetails.license} onChange={e => setDlDetails(prev => ({...prev, license: e.target.value.toUpperCase()}))} className="flex-1 [&>input]:uppercase [&>input]:h-10" />
               <DenseInput label="DOB" type="date" value={dlDetails.dob} onChange={e => setDlDetails(prev => ({...prev, dob: e.target.value}))} className="w-[120px] [&>input]:h-10" />
             </div>
             <Button 
               variant="primary"
               type="button"
               onClick={handleFetchDL} 
               disabled={fetchingDl || !dlDetails.license || !dlDetails.dob}
               className="h-10 mt-1 px-4 text-sm w-full shadow-sm hover:shadow"
             >
               {fetchingDl ? 'Verifying...' : 'Verify & Check Eligibility'}
             </Button>
             
             {/* DL Verified Badge */}
             {dlData && (
               <div className="mt-2 flex flex-col gap-1.5 p-2 bg-blue-50 border border-blue-100 rounded-md">
                 <div className="flex items-center justify-between">
                   <span className={`text-[10px] font-black tracking-wider uppercase px-2 py-0.5 rounded-sm ${dlData.status === 'ACTIVE' ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'}`}>
                     {dlData.status}
                   </span>
                   {/* Eligibility */}
                   {(() => {
                      const validClasses = ['TRANS', 'HTV', 'HMV', 'HGMV', 'MGV', 'MGMV'];
                      const hasValidClass = dlData.vehicle_classes?.some(c => validClasses.includes(c?.toUpperCase()));
                      let isExpired = false;
                      if (dlData.validity_tr && dlData.validity_tr !== '-' && dlData.validity_tr !== 'NA') {
                        const parts = dlData.validity_tr.split('-');
                        if (parts.length === 3) {
                          const [day, month, year] = parts;
                          const expiryDate = new Date(`${year}-${month}-${day}`);
                          if (expiryDate < new Date()) isExpired = true;
                        } else isExpired = true;
                      } else isExpired = true;

                      if (!hasValidClass) {
                        return <span className="text-[10px] font-black tracking-wider text-rose-700 uppercase bg-rose-100 px-2 py-0.5 rounded-sm flex items-center gap-1 border border-rose-200">Missing Heavy Class</span>;
                      } else if (isExpired) {
                        return <span className="text-[10px] font-black tracking-wider text-rose-700 uppercase bg-rose-100 px-2 py-0.5 rounded-sm flex items-center gap-1 border border-rose-200">TR Expired</span>;
                      } else {
                        return <span className="text-[10px] font-black tracking-wider text-emerald-700 uppercase bg-emerald-100 px-2 py-0.5 rounded-sm flex items-center gap-1 border border-emerald-200">Transport Eligible</span>;
                      }
                   })()}
                 </div>
                 <div className="text-xs font-bold text-slate-800 flex items-center gap-1">
                   {dlData.owner_name} {dlData.owner_name?.includes('*') && <span className="text-[9px] font-black tracking-wider text-rose-500 bg-rose-50 px-1 py-0.5 rounded uppercase">Masked</span>}
                 </div>
                 <div className="flex justify-between text-[10px] font-bold text-slate-500">
                   <span>TR Val: {dlData.validity_tr}</span>
                   <span>Class: {dlData.vehicle_classes?.join(', ')}</span>
                 </div>
               </div>
             )}
           </div>

            <div className="flex gap-3">
             <DenseInput label="Driver Name" value={lorryDetails.driverName} onChange={e => setLorryDetails(prev => ({...prev, driverName: e.target.value}))} className="w-1/2 [&>input]:h-10" />
             <DenseInput label="Driver Phone" value={lorryDetails.driverPhone} onChange={e => setLorryDetails(prev => ({...prev, driverPhone: e.target.value}))} className="w-1/2 [&>input]:h-10" />
           </div>
        </div>
      </div>
    </GlassCard>
  );
});
