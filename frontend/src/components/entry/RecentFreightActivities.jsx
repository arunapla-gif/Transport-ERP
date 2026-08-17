import React, { memo } from 'react';
import { FileText } from 'lucide-react';

const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/80 backdrop-blur-2xl border border-white/60 rounded-xl p-3.5 shadow-[0_4px_20px_rgb(79,70,229,0.04)] relative overflow-hidden transition-all duration-300 hover:shadow-[0_4px_20px_rgb(79,70,229,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

const RecentFreightActivities = memo(({
  activeGc,
  recentActivities
}) => {
  if (activeGc || recentActivities.length === 0) return null;

  return (
    <div className="mt-8 animate-in fade-in slide-in-from-bottom-4">
      <div className="flex items-center gap-2 mb-3 px-1">
        <div className="bg-slate-100 text-slate-500 p-1.5 rounded-lg border border-slate-200"><FileText size={16} /></div>
        <h3 className="font-bold text-sm text-slate-700 tracking-tight uppercase">Recent Freight Entries</h3>
      </div>
      <GlassCard className="!p-0 border-slate-200/60 shadow-sm">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50/80 text-[10px] font-extrabold text-slate-400 uppercase tracking-wider border-b border-slate-100">
                <th className="p-3 pl-5">GC Number</th>
                <th className="p-3">Consignee</th>
                <th className="p-3 text-center">Bundles</th>
                <th className="p-3 text-right">Freight Total</th>
                <th className="p-3 text-right pr-5">Advance</th>
              </tr>
            </thead>
            <tbody className="text-sm font-semibold text-slate-600 divide-y divide-slate-50">
              {recentActivities.map((gc, i) => {
                const bundles = gc.goods ? gc.goods.reduce((s, item) => s + (item.articleCount || 0), 0) : 0;
                return (
                  <tr key={gc.id || i} className="hover:bg-slate-50/50 transition-colors">
                    <td className="p-3 pl-5 font-bold text-indigo-700">{gc.gcNumber}</td>
                    <td className="p-3 truncate max-w-[200px]">{gc.consignee?.name || '-'}</td>
                    <td className="p-3 text-center text-slate-800 font-bold">{bundles}</td>
                    <td className="p-3 text-right font-black text-emerald-600">₹{gc.freightTotal?.toFixed(2)}</td>
                    <td className="p-3 text-right pr-5 font-medium text-slate-500">₹{gc.advancePaid?.toFixed(2) || '0.00'}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </GlassCard>
    </div>
  );
});

export default RecentFreightActivities;
