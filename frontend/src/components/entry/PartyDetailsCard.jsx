import React from 'react';
import { GlassCard, denseSearchableSelectClass } from '../ui/DensePrimitives';
import { Button } from '../ui/Button';
import { AsyncSearchableSelect } from '../ui/AsyncSearchableSelect';
import { Building2, MapPin } from 'lucide-react';

export const PartyDetailsCard = React.memo(({ 
  partyDetails, 
  fetchConsignorsAsync, 
  handleConsignorChange, 
  fetchConsigneesAsync, 
  handleConsigneeChange,
  fieldErrors = {}
}) => {
  return (
    <div className="grid grid-cols-2 gap-4">
      <GlassCard>
         <h3 className="font-bold text-sm text-slate-800 mb-3 flex items-center gap-2 border-b border-slate-100 pb-2">
           <Building2 size={16} className="text-blue-500"/> Consignor
           {partyDetails.isNewConsignor && <span className="bg-emerald-500 text-white text-[9px] px-1.5 py-0.5 rounded shadow-sm animate-pulse ml-auto uppercase">Newly Saved</span>}
         </h3>
         <div className="flex items-end gap-2">
           <div className="flex-1">
             <AsyncSearchableSelect 
               id="consignor-select" 
               label="Search Consignor *" 
               error={fieldErrors.consignor}
               placeholder="Type to search..." 
               fetchOptions={fetchConsignorsAsync} 
               value={partyDetails.consignorId?.toString()} 
               initialOption={partyDetails.consignorData ? { value: partyDetails.consignorId.toString(), label: partyDetails.consignorData.name, raw: partyDetails.consignorData } : null}
               onChange={handleConsignorChange} 
               autoFocus 
               className={denseSearchableSelectClass} 
             />
           </div>
           {partyDetails.consignorId && (
             <Button variant="custom" type="button" onClick={() => window.open('/consignor-master', '_blank')} className="h-9 w-9 p-0 flex items-center justify-center rounded-lg bg-blue-50 text-blue-600 hover:bg-blue-100 border border-blue-200 transition-colors" title="Edit Consignor">
               <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M17 3a2.828 2.828 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"></path></svg>
             </Button>
           )}
         </div>
         <div className="text-xs text-slate-500 mt-2 bg-slate-50 p-2 rounded border border-slate-100 min-h-[40px]">{partyDetails.consignorAddressPreview || 'No Address Selected'}</div>
         <div className="text-xs font-mono font-bold text-indigo-700 mt-1 uppercase flex items-center gap-2">
            {partyDetails.consignorGstin || 'No GSTIN'}
            {partyDetails.consignorGstin && <span className="bg-emerald-100 text-emerald-700 px-1.5 py-0.5 rounded border border-emerald-200 text-[9px] font-black tracking-wider flex items-center gap-1 shrink-0"><span className="text-emerald-500">✓</span> VERIFIED</span>}
         </div>
      </GlassCard>
      
      <GlassCard>
         <h3 className="font-bold text-sm text-slate-800 mb-3 flex items-center gap-2 border-b border-slate-100 pb-2">
           <MapPin size={16} className="text-emerald-500"/> Consignee
           {partyDetails.isNewConsignee && <span className="bg-emerald-500 text-white text-[9px] px-1.5 py-0.5 rounded shadow-sm animate-pulse ml-auto uppercase">Newly Saved</span>}
         </h3>
         <div className="flex items-end gap-2">
           <div className="flex-1">
             <AsyncSearchableSelect 
               id="consignee-select" 
               label="Search Consignee *" 
               error={fieldErrors.consignee}
               placeholder="Type to search..." 
               fetchOptions={fetchConsigneesAsync} 
               value={partyDetails.consigneeId?.toString()} 
               initialOption={partyDetails.consigneeData ? { value: partyDetails.consigneeId.toString(), label: partyDetails.consigneeData.name, raw: partyDetails.consigneeData } : null}
               onChange={handleConsigneeChange} 
               className={denseSearchableSelectClass} 
             />
           </div>
           {partyDetails.consigneeId && (
             <Button variant="custom" type="button" onClick={() => window.open('/consignee-master', '_blank')} className="h-9 w-9 p-0 flex items-center justify-center rounded-lg bg-blue-50 text-blue-600 hover:bg-blue-100 border border-blue-200 transition-colors" title="Edit Consignee">
               <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M17 3a2.828 2.828 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"></path></svg>
             </Button>
           )}
         </div>
         <div className="text-xs text-slate-500 mt-2 bg-slate-50 p-2 rounded border border-slate-100 min-h-[40px]">{partyDetails.consigneeAddressPreview || 'No Address Selected'}</div>
         <div className="text-xs font-mono font-bold text-emerald-700 mt-1 uppercase flex items-center gap-2">
            {partyDetails.consigneeGstin || 'No GSTIN'}
            {partyDetails.consigneeGstin && <span className="bg-emerald-100 text-emerald-700 px-1.5 py-0.5 rounded border border-emerald-200 text-[9px] font-black tracking-wider flex items-center gap-1 shrink-0"><span className="text-emerald-500">✓</span> VERIFIED</span>}
         </div>
      </GlassCard>
    </div>
  );
});
