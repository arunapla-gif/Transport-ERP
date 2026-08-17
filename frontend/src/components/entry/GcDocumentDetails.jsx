import React from 'react';
import { GlassCard, DenseInput, DenseSelect } from '../ui/DensePrimitives';
import { FileText } from 'lucide-react';

export const GcDocumentDetails = React.memo(({ 
  gcDetails, 
  setGcDetails, 
  branch, 
  godowns,
  fieldErrors = {}
}) => {
  return (
    <GlassCard>
      <h3 className="font-bold text-sm text-slate-800 mb-3 flex items-center gap-2 border-b border-slate-100 pb-2">
        <FileText size={16} className="text-indigo-500"/> Document Details
      </h3>
      <div className="grid grid-cols-4 gap-3">
        <DenseSelect 
          label="Fin. Year" 
          options={['2026-2027', '2025-2026']} 
          value={gcDetails.financialYear} 
          onChange={e => setGcDetails(prev => ({...prev, financialYear: e.target.value}))} 
        />
        <DenseInput 
          label="Booking Date" 
          type="date" 
          value={gcDetails.date} 
          onChange={e => setGcDetails(prev => ({...prev, date: e.target.value}))} 
        />
        <DenseInput 
          label="Time" 
          type="time" 
          value={gcDetails.time} 
          onChange={e => setGcDetails(prev => ({...prev, time: e.target.value}))} 
        />
        <DenseSelect 
          label={branch === 'BNG' ? 'Godown' : 'Godown *'} 
          error={fieldErrors.godown}
          options={[{value: '', label: 'Select Godown'}, ...godowns.map(g => ({value: g.name, label: g.name}))]} 
          value={gcDetails.godown || ''} 
          onChange={e => setGcDetails(prev => ({...prev, godown: e.target.value}))} 
        />
      </div>
    </GlassCard>
  );
});
