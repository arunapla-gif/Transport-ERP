import React, { memo } from 'react';
import { Button } from '../ui/Button';
import { Edit3, Printer } from 'lucide-react';

const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/90 backdrop-blur-2xl border border-white/60 rounded-xl p-4 md:p-5 shadow-[0_4px_20px_rgb(79,70,229,0.04)] relative transition-all duration-300 hover:shadow-[0_4px_20px_rgb(79,70,229,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

const WarehouseRecentCard = memo(({
  recentEntry,
  handleEditRecent,
  handlePrintRecent
}) => {
  if (!recentEntry) return null;

  return (
    <GlassCard className="mt-2 border-l-4 border-l-indigo-500 animate-in fade-in slide-in-from-bottom-4 duration-500 print:hidden">
      <div className="flex justify-between items-start mb-3">
        <div>
          <h3 className="font-black text-slate-800 text-sm uppercase tracking-wider">
            Last Saved Entry <span className="text-indigo-600 ml-1">#{recentEntry.receiptNo}</span>
          </h3>
          <p className="text-[10px] font-bold text-slate-500">
            {new Date(recentEntry.createdAt).toLocaleString('en-IN')}
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="icon" onClick={handleEditRecent} className="p-2 w-9 h-9 text-blue-600 bg-blue-50 hover:bg-blue-100 bg-transparent flex items-center justify-center" title="Edit">
            <Edit3 size={16} />
          </Button>
          <Button variant="icon" onClick={handlePrintRecent} className="p-2 w-9 h-9 text-indigo-600 bg-indigo-50 hover:bg-indigo-100 bg-transparent flex items-center justify-center" title="Print Slip">
            <Printer size={16} />
          </Button>
        </div>
      </div>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
        <div>
          <p className="text-[10px] font-bold text-slate-400 uppercase">Consignor</p>
          <p className="font-bold text-slate-800 truncate">{recentEntry.consignorName}</p>
        </div>
        <div>
          <p className="text-[10px] font-bold text-slate-400 uppercase">Consignee</p>
          <p className="font-bold text-slate-800 truncate">{recentEntry.consigneeName}</p>
        </div>
        <div>
          <p className="text-[10px] font-bold text-slate-400 uppercase">Articles</p>
          <p className="font-black text-indigo-600">{recentEntry.articles}</p>
        </div>
        <div>
          <p className="text-[10px] font-bold text-slate-400 uppercase">Godown</p>
          <p className="font-bold text-slate-800">{recentEntry.godownNo}</p>
        </div>
      </div>
    </GlassCard>
  );
});

export default WarehouseRecentCard;
